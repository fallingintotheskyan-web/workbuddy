"""Deterministic in-process ASR used for tests and for demos without API keys.

It ignores audio content but reacts to how much audio it received, so the whole
transport/UI loop can be exercised end to end.
"""

from __future__ import annotations

import asyncio
from typing import AsyncIterator

from .base import AsrEvent, AsrEventType, AsrProvider

_BYTES_PER_SECOND = 16000 * 2  # 16 kHz, mono, s16le


class FakeAsrProvider(AsrProvider):
    name = "fake"

    def __init__(self) -> None:
        self._queue: asyncio.Queue[AsrEvent | None] = asyncio.Queue()
        self._received_bytes = 0
        self._last_partial_second = 0.0
        self._next_final_second = 3.0
        self._final_count = 0

    async def open(self, *, language: str) -> None:
        self._received_bytes = 0
        self._last_partial_second = 0.0
        self._next_final_second = 3.0

    async def send(self, pcm: bytes) -> None:
        self._received_bytes += len(pcm)
        seconds = self._received_bytes / _BYTES_PER_SECOND
        if seconds - self._last_partial_second >= 0.8:
            self._last_partial_second = seconds
            await self._queue.put(
                AsrEvent(
                    AsrEventType.PARTIAL,
                    f"演示识别中… 已收到 {seconds:.1f} 秒音频",
                )
            )
        # Emit a final every 3 seconds of streamed audio so the device demo
        # also shows locked sentences without needing a silence detector.
        while seconds >= self._next_final_second:
            self._next_final_second += 3.0
            await self._emit_final()

    async def flush(self) -> None:
        await self._emit_final()

    async def _emit_final(self) -> None:
        self._final_count += 1
        await self._queue.put(
            AsrEvent(
                AsrEventType.FINAL,
                f"演示第 {self._final_count} 句：这是来自 fake ASR 的最终字幕。",
                confidence=0.99,
            )
        )

    async def close(self) -> None:
        await self._queue.put(None)

    async def events(self) -> AsyncIterator[AsrEvent]:
        while True:
            event = await self._queue.get()
            if event is None:
                return
            yield event
