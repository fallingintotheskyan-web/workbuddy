"""Server configuration. All secrets live here (loaded from server/.env)."""

from __future__ import annotations

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_SERVER_ROOT = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_SERVER_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # ASR
    asr_provider: str = "deepgram"
    deepgram_api_key: str = ""
    deepgram_model: str = "nova-2"
    asr_default_language: str = "zh"
    asr_endpointing_ms: int = 1500
    asr_utterance_end_ms: int = 1500
    asr_idle_disconnect_s: int = 0

    # Translation (wired up in phase 4)
    translate_provider: str = "deepl"
    deepl_api_key: str = ""
    deepl_api_url: str = "https://api-free.deepl.com"

    # HTTP / WS
    ws_host: str = "0.0.0.0"
    ws_port: int = 8000
    log_dir: str = "logs"


settings = Settings()
