"""FastAPI entrypoint for the ASR/translation proxy."""

from __future__ import annotations

import logging

from fastapi import FastAPI

from .config import settings
from .ws import router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-7s %(name)s: %(message)s",
)

app = FastAPI(title="Classroom Notes API", version="0.2.0")
app.include_router(router)


@app.get("/health")
async def health() -> dict[str, object]:
    return {
        "status": "ok",
        "asrProvider": settings.asr_provider,
        "translateProvider": settings.translate_provider,
        "sampleRate": 16000,
        "encoding": "pcm_s16le",
    }
