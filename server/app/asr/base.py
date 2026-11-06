"""ASR provider abstraction.

Every provider consumes 16 kHz / mono / 16-bit PCM and emits partial and final
transcript events. Swapping vendors must not require touching the WebSocket
layer, the session logic, or the client.
"""

from __future__ import annotations

import abc
from dataclasses import dataclass
from enum import Enum
from typing import AsyncIterator


class AsrEventType(str, Enum):
    PARTIAL = "partial"
    FINAL = "final"
    ERROR = "error"


@dataclass(slots=True)
class AsrEvent:
    type: AsrEventType
    text: str = ""
    confidence: float | None = None
    # Milliseconds of audio covered by a final result, when the provider knows it.
    duration_ms: int | None = None


class AsrProvider(abc.ABC):
    """Streaming speech-to-text backend."""

    name: str = "base"

    @abc.abstractmethod
    async def open(self, *, language: str) -> None:
        """Open the upstream stream for the given language (ISO code or 'auto')."""

    @abc.abstractmethod
    async def send(self, pcm: bytes) -> None:
        """Forward a chunk of 16-bit little-endian mono PCM."""

    @abc.abstractmethod
    async def flush(self) -> None:
        """Ask the provider to finalize the current utterance."""

    @abc.abstractmethod
    async def close(self) -> None:
        """Close the upstream stream and stop emitting events."""

    @abc.abstractmethod
    def events(self) -> AsyncIterator[AsrEvent]:
        """Yield transcript events until the provider is closed."""
