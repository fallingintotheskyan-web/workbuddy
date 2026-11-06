"""Azure Speech-to-Text adapter skeleton.

See google.py for the intended implementation notes. Azure's push stream wants
16 kHz / 16-bit / mono PCM as well, so the transport layer does not need to
change when this adapter is filled in.
"""

from __future__ import annotations

from typing import AsyncIterator

from .base import AsrEvent, AsrProvider


class AzureAsrProvider(AsrProvider):
    name = "azure"

    async def open(self, *, language: str) -> None:
        raise NotImplementedError(
            "AzureAsrProvider is a skeleton. Configure ASR_PROVIDER=deepgram "
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
