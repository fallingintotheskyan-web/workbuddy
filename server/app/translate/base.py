"""Translation provider abstraction.

Only final sentences are translated; partials never reach this interface.
"""

from __future__ import annotations

import abc


class TranslateProvider(abc.ABC):
    name: str = "base"

    @abc.abstractmethod
    async def translate(self, text: str, target: str) -> str:
        """Translate one sentence to `target` (lowercase 'zh'/'en'/'ru')."""
