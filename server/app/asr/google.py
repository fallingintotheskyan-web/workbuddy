"""Google Cloud Speech-to-Text adapter skeleton.

Intentionally not implemented yet: the default provider is Deepgram and adding a
half-working vendor adapter would be worse than none. Keep the method signatures
in sync with AsrProvider so swapping it in later is mechanical:

1. Open a streaming recognize stream (LINEAR16, 16 kHz, mono).
2. Map `interim_results` callbacks to AsrEvent(PARTIAL).
3. Map final results to AsrEvent(FINAL).
4. Implement flush() by sending the last chunk with `single_utterance` semantics
   or by reopening the stream.
"""

from __future__ import annotations

from typing import AsyncIterator

from .base import AsrEvent, AsrProvider


class GoogleAsrProvider(AsrProvider):
    name = "google"

    async def open(self, *, language: str) -> None:
        raise NotImplementedError(
            "GoogleAsrProvider is a skeleton. Configure ASR_PROVIDER=deepgram "
            "or implement this adapter before selecting it."
        )

    async def send(self, pcm: bytes) -> None:
        raise NotImplementedError

    async def flush(self) -> None:
        raise NotImplementedError

    async def close(self) -> None:
        return None

    async def events(self) -> AsyncIterator[AsrEvent]:
        return
        yield  # pragma: no cover - makes this an async generator
