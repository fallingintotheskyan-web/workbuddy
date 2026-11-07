"""Deterministic translator for tests. Counts calls so tests can assert that a
disabled toggle never reaches the translation layer."""

from __future__ import annotations

from .base import TranslateProvider


class FakeTranslateProvider(TranslateProvider):
    name = "fake"
    calls = 0

    @classmethod
    def reset(cls) -> None:
        cls.calls = 0

    async def translate(self, text: str, target: str) -> str:
        FakeTranslateProvider.calls += 1
        return f"[{target.upper()}] {text}"
