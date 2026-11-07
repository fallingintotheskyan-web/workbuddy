"""DeepL translation adapter.

DeepL now requires the API key in an `Authorization: DeepL-Auth-Key <key>`
header (the legacy `auth_key` form field is rejected with 403).
"""

from __future__ import annotations

import logging

import httpx

from .base import TranslateProvider
from .cache import TranslationCache

logger = logging.getLogger(__name__)


class DeepLTranslateProvider(TranslateProvider):
    name = "deepl"

    def __init__(self, api_key: str, api_url: str, cache: TranslationCache | None = None) -> None:
        self._api_key = api_key
        self._api_url = (api_url or "https://api-free.deepl.com").rstrip("/")
        self._cache = cache

    async def translate(self, text: str, target: str) -> str:
        if not self._api_key:
            raise RuntimeError("DEEPL_API_KEY is not configured on the server")

        if self._cache is not None:
            hit = self._cache.get(text, target)
            if hit is not None:
                return hit

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                f"{self._api_url}/v2/translate",
                headers={"Authorization": f"DeepL-Auth-Key {self._api_key}"},
                data={"text": text, "target_lang": target.upper()},
            )
            response.raise_for_status()
            payload = response.json()
            translation = payload["translations"][0]["text"]

        if self._cache is not None:
            self._cache.put(text, target, translation)
        return translation
