"""Small LRU cache keyed by (text, target) so repeated sentences are not
re-sent to the translation API."""

from __future__ import annotations

from collections import OrderedDict


class TranslationCache:
    def __init__(self, maxsize: int = 1000) -> None:
        self._maxsize = maxsize
        self._store: OrderedDict[tuple[str, str], str] = OrderedDict()

    def get(self, text: str, target: str) -> str | None:
        return self._store.get((text, target))

    def put(self, text: str, target: str, translation: str) -> None:
        key = (text, target)
        if key in self._store:
            self._store.move_to_end(key)
        self._store[key] = translation
        while len(self._store) > self._maxsize:
            self._store.popitem(last=False)

    def __len__(self) -> int:
        return len(self._store)
