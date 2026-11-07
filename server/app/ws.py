"""WebSocket bridge between the Flutter client and the ASR provider.

Wire format (client -> server):
  {"type":"start","sourceLanguage":"auto|zh|en|ru",
   "sampleRate":16000,"channels":1,"encoding":"pcm_s16le"}
  <binary frames: 16 kHz mono s16le PCM>
  {"type":"flush"}                       # silence detected, finalize now
  {"type":"configure","translate":{...}} # phase 4
  {"type":"stop"}                        # finalize and end
  {"type":"ping"}

Server -> client:
  {"type":"ready","sessionId":...,"provider":...,"sampleRate":16000}
  {"type":"partial","text":...}
  {"type":"final","id":...,"text":...}
  {"type":"status","state":"listening|paused|error","detail":...}
  {"type":"error","message":...}
  {"type":"pong"}
"""

from __future__ import annotations

import asyncio
import json
import logging
import uuid

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from .asr.base import AsrEventType, AsrProvider
from .asr.factory import create_asr_provider
from .config import settings
from .translate.base import TranslateProvider
from .translate.factory import create_translate_provider

logger = logging.getLogger(__name__)
router = APIRouter()

SAMPLE_RATE = 16000
CHANNELS = 1
ENCODING = "pcm_s16le"
START_TIMEOUT_S = 10.0


class ProtocolError(ValueError):
    pass


class AsrConnection:
    def __init__(self, websocket: WebSocket) -> None:
        self.websocket = websocket
        self.session_id = uuid.uuid4().hex[:12]
        self.provider: AsrProvider | None = None
        self.translator: TranslateProvider | None = None
        self.translate_enabled = False
        self.translate_target = "en"
        self._translate_tasks: list[asyncio.Task[None]] = []
        self.pump: asyncio.Task[None] | None = None
        self.sequence = 0
        self.audio_bytes = 0
        self.language = settings.asr_default_language

    async def run(self) -> None:
        await self.websocket.accept()
        try:
            start = await asyncio.wait_for(self.websocket.receive_json(), timeout=START_TIMEOUT_S)
            self._handle_start(start)

            self.provider = create_asr_provider()
            self.translator = create_translate_provider()
            await self.provider.open(language=self.language)
            await self._send(
                {
                    "type": "ready",
                    "sessionId": self.session_id,
                    "provider": self.provider.name,
                    "sampleRate": SAMPLE_RATE,
                    "encoding": ENCODING,
                    "language": self.language,
                }
            )
            self.pump = asyncio.create_task(self._pump_events(), name=f"asr-pump-{self.session_id}")
            await self._receive_loop()
        except ProtocolError as exc:
            await self._safe_error(str(exc))
        except WebSocketDisconnect:
            logger.info("client disconnected session=%s", self.session_id)
        except asyncio.TimeoutError:
            await self._safe_error("timed out waiting for start message")
        except Exception as exc:  # noqa: BLE001 - report and close cleanly
            logger.exception("session %s failed", self.session_id)
            await self._safe_error(f"session failed: {exc}")
        finally:
            await self._shutdown()

    def _handle_start(self, payload: object) -> None:
        if not isinstance(payload, dict) or payload.get("type") != "start":
            raise ProtocolError("first message must be {'type':'start', ...}")
        sample_rate = int(payload.get("sampleRate", 0))
        channels = int(payload.get("channels", 0))
        encoding = str(payload.get("encoding", "")).lower()
        if sample_rate != SAMPLE_RATE:
            raise ProtocolError(f"sampleRate must be {SAMPLE_RATE}, got {sample_rate}")
        if channels != CHANNELS:
            raise ProtocolError(f"channels must be {CHANNELS}, got {channels}")
        if encoding != ENCODING:
            raise ProtocolError(f"encoding must be {ENCODING}, got {encoding}")
        requested = str(payload.get("sourceLanguage", "auto")).lower()
        if requested in {"auto", ""}:
            self.language = settings.asr_default_language
        elif requested in {"zh", "en", "ru"}:
            self.language = requested
        else:
            raise ProtocolError(f"unsupported sourceLanguage: {requested}")

    async def _receive_loop(self) -> None:
        assert self.provider is not None
        while True:
            message = await self.websocket.receive()
            if message.get("type") == "websocket.disconnect":
                return

            data = message.get("bytes")
            if data is not None:
                if len(data) % 2 != 0:
                    await self._send({"type": "error", "message": "PCM payload must be 16-bit aligned"})
                    continue
                self.audio_bytes += len(data)
                await self.provider.send(data)
                continue

            raw = message.get("text")
            if raw is None:
                continue
            try:
                payload = json.loads(raw)
            except ValueError:
                await self._send({"type": "error", "message": "control messages must be JSON"})
                continue

            kind = payload.get("type") if isinstance(payload, dict) else None
            if kind == "flush":
                await self.provider.flush()
            elif kind == "configure":
                translate = payload.get("translate")
                if isinstance(translate, dict):
                    self.translate_enabled = bool(translate.get("enabled"))
                    target = str(translate.get("target", "en")).lower()
                    if target in {"zh", "en", "ru"}:
                        self.translate_target = target
            elif kind == "stop":
                await self.provider.flush()
                await asyncio.sleep(0.05)
                return
            elif kind == "ping":
                await self._send({"type": "pong"})
            else:
                await self._send({"type": "error", "message": f"unknown message type: {kind}"})

    async def _pump_events(self) -> None:
        assert self.provider is not None
        try:
            async for event in self.provider.events():
                if event.type == AsrEventType.PARTIAL:
                    await self._send({"type": "partial", "text": event.text})
                elif event.type == AsrEventType.FINAL:
                    self.sequence += 1
                    final_id = f"{self.session_id}-{self.sequence}"
                    await self._send(
                        {
                            "type": "final",
                            "id": final_id,
                            "text": event.text,
                            "seq": self.sequence,
                        }
                    )
                    # Translate final sentences only, and only when enabled.
                    if (
                        self.translate_enabled
                        and self.translator is not None
                        and event.text.strip()
                    ):
                        self._translate_tasks.append(
                            asyncio.create_task(
                                self._translate_and_send(final_id, event.text, self.translate_target),
                                name=f"translate-{final_id}",
                            )
                        )
                elif event.type == AsrEventType.ERROR:
                    await self._send({"type": "error", "message": event.text})
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # noqa: BLE001
            logger.warning("event pump failed session=%s: %s", self.session_id, exc)

    async def _send(self, payload: dict) -> None:
        try:
            await self.websocket.send_json(payload)
        except (RuntimeError, WebSocketDisconnect):
            pass

    async def _translate_and_send(self, final_id: str, text: str, target: str) -> None:
        assert self.translator is not None
        try:
            translation = await self.translator.translate(text, target)
            if translation:
                await self._send(
                    {
                        "type": "translation",
                        "id": final_id,
                        "text": translation,
                        "target": target,
                    }
                )
        except Exception as exc:  # noqa: BLE001 - translation is best effort
            logger.warning("translation failed for %s: %s", final_id, exc)

    async def _safe_error(self, message: str) -> None:
        await self._send({"type": "error", "message": message})

    async def _shutdown(self) -> None:
        for task in self._translate_tasks:
            task.cancel()
        if self._translate_tasks:
            await asyncio.gather(*self._translate_tasks, return_exceptions=True)
        self._translate_tasks.clear()
        if self.pump is not None:
            self.pump.cancel()
            try:
                await self.pump
            except (asyncio.CancelledError, Exception):  # noqa: BLE001
                pass
        if self.provider is not None:
            try:
                await self.provider.close()
            except Exception:  # noqa: BLE001
                pass
        try:
            await self.websocket.close()
        except Exception:  # noqa: BLE001
            pass


@router.websocket("/ws/asr")
async def asr_endpoint(websocket: WebSocket) -> None:
    await AsrConnection(websocket).run()
