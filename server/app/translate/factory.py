"""Translation provider selection. `none` disables translation entirely."""

from __future__ import annotations

from ..config import settings
from .base import TranslateProvider
from .cache import TranslationCache
from .deepl import DeepLTranslateProvider
from .fake import FakeTranslateProvider


def create_translate_provider() -> TranslateProvider | None:
    name = (settings.translate_provider or "none").strip().lower()
    if name in {"", "none"}:
        return None
    if name == "deepl":
        return DeepLTranslateProvider(
            api_key=settings.deepl_api_key,
            api_url=settings.deepl_api_url,
            cache=TranslationCache(),
        )
    if name == "fake":
        return FakeTranslateProvider()
    raise ValueError(f"translate provider '{name}' is not implemented")
