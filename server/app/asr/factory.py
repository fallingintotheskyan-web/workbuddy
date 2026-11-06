"""Provider selection. One place to change when swapping ASR vendors."""

from __future__ import annotations

from .base import AsrProvider
from .deepgram import DeepgramAsrProvider
from .fake import FakeAsrProvider
from ..config import settings


def create_asr_provider() -> AsrProvider:
    name = (settings.asr_provider or "deepgram").strip().lower()
    if name == "deepgram":
        return DeepgramAsrProvider(
            api_key=settings.deepgram_api_key,
            model=settings.deepgram_model,
            endpointing_ms=settings.asr_endpointing_ms,
            utterance_end_ms=settings.asr_utterance_end_ms,
        )
    if name == "fake":
        return FakeAsrProvider()
    raise ValueError(
        f"ASR provider '{name}' is not implemented. Use deepgram or fake."
    )
