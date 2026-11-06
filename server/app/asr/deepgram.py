"""Deepgram streaming ASR adapter (nova-2 covers zh / en / ru).

Docs: https://developers.deepgram.com/docs/streaming-audio-transcription
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import AsyncIterator
from urllib.parse import urlencode

import websockets

from .base import AsrEvent, AsrEventType, AsrProvider

logger = logging.getLogger(__name__)

_KEEPALIVE_SECONDS = 5.0


class DeepgramAsrProvider(AsrProvider):
    name = "deepgram"

    def __init__(
        self,
        *,
        api_key: str,
        model: str = "nova-2",
        sample_rate: int = 16000,
        endpointing_ms: int = 1500,
        utterance_end_ms: int = 1500,
    ) -> None:
        self._api_key = api_key
        self._model = model
        self._sample_rate = sample_rate
        self._endpointing_ms = endpointing_ms
        self._utterance_end_ms = utterance_end_ms
        self._ws: websockets.WebSocketClientProtocol | None = None
        self._queue: asyncio.Queue[AsrEvent | None] = asyncio.Queue()
        self._receiver: asyncio.Task[None] | None = None
        self._keepalive: asyncio.Task[None] | None = None
        self._language = "zh"
        self._last_final = ""

    async def open(self, *, language: str) -> None:
        if not self._api_key:
            raise RuntimeError("DEEPGRAM_API_KEY is not configured on the server")
        self._language = language or "zh"

        params = {
            "model": self._model,
            "encoding": "linear16",
            "sample_rate": str(self._sample_rate),
            "channels": "1",
            "interim_results": "true",
            "smart_format": "true",
            "endpointing": str(self._endpointing_ms),
            "utterance_end_ms": str(self._utterance_end_ms),
        }
        if self._language == "auto":
            params["detect_language"] = "true"
        else:
            params["language"] = self._language

        url = f"wss://api.deepgram.com/v1/listen?{urlencode(params)}"
        headers = {"Authorization": f"Token {self._api_key}"}
        try:
            self._ws = await websockets.connect(url, additional_headers=headers, max_size=2**22)
        except TypeError:  # websockets < 14
            self._ws = await websockets.connect(url, extra_headers=headers, max_size=2**22)

        self._receiver = asyncio.create_task(self._receive_loop(), name="deepgram-recv")
        self._keepalive = asyncio.create_task(self._keepalive_loop(), name="deepgram-keepalive")

    async def send(self, pcm: bytes) -> None:
        if self._ws is None:
            raise RuntimeError("Deepgram stream is not open")
        await self._ws.send(pcm)

    async def flush(self) -> None:
        if self._ws is None:
            return
        await self._ws.send(json.dumps({"type": "Finalize"}))

    async def close(self) -> None:
        for task in (self._keepalive, self._receiver):
            if task is not None:
                task.cancel()
        if self._ws is not None:
            try:
                await self._ws.send(json.dumps({"type": "CloseStream"}))
            except Exception:  # noqa: BLE001 - best effort on shutdown
                pass
            try:
                await self._ws.close()
            except Exception:  # noqa: BLE001
                pass
            self._ws = None
        await self._queue.put(None)

    async def events(self) -> AsyncIterator[AsrEvent]:
        while True:
            event = await self._queue.get()
            if event is None:
                return
            yield event

    async def _keepalive_loop(self) -> None:
        try:
            while True:
                await asyncio.sleep(_KEEPALIVE_SECONDS)
                if self._ws is not None:
                    await self._ws.send(json.dumps({"type": "KeepAlive"}))
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # noqa: BLE001
            logger.warning("Deepgram keepalive failed: %s", exc)

    async def _receive_loop(self) -> None:
        assert self._ws is not None
        try:
            async for raw in self._ws:
                self._handle_message(raw)
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # noqa: BLE001
            logger.warning("Deepgram receive loop ended: %s", exc)
            await self._queue.put(AsrEvent(AsrEventType.ERROR, f"ASR stream error: {exc}"))
        finally:
            await self._queue.put(None)

    def _handle_message(self, raw: str | bytes) -> None:
        try:
            message = json.loads(raw)
        except (TypeError, ValueError):
            return

        kind = message.get("type")
        if kind == "Results":
            alternatives = message.get("channel", {}).get("alternatives") or []
            if not alternatives:
                return
            text = (alternatives[0].get("transcript") or "").strip()
            if not text:
                return
            is_final = bool(message.get("is_final") or message.get("speech_final"))
            if is_final:
                if text == self._last_final:
                    return
                self._last_final = text
                self._queue.put_nowait(AsrEvent(AsrEventType.FINAL, text))
            else:
                self._queue.put_nowait(AsrEvent(AsrEventType.PARTIAL, text))
        elif kind == "Error":
            detail = message.get("description") or message.get("message") or "unknown Deepgram error"
            self._queue.put_nowait(AsrEvent(AsrEventType.ERROR, str(detail)))
