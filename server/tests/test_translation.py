from fastapi.testclient import TestClient

from app.main import app
from app.translate.cache import TranslationCache
from app.translate.fake import FakeTranslateProvider

START = {
    "type": "start",
    "sourceLanguage": "zh",
    "sampleRate": 16000,
    "channels": 1,
    "encoding": "pcm_s16le",
}
ONE_SECOND_PCM = b"\x00\x00" * 16000


def test_final_triggers_translation_when_enabled() -> None:
    FakeTranslateProvider.reset()
    with TestClient(app) as client:
        with client.websocket_connect("/ws/asr") as websocket:
            websocket.send_json(START)
            assert websocket.receive_json()["type"] == "ready"

            websocket.send_json({"type": "configure", "translate": {"enabled": True, "target": "en"}})
            websocket.send_bytes(ONE_SECOND_PCM)
            assert websocket.receive_json()["type"] == "partial"

            websocket.send_json({"type": "flush"})
            final = websocket.receive_json()
            assert final["type"] == "final"

            translation = websocket.receive_json()
            assert translation["type"] == "translation"
            assert translation["id"] == final["id"]
            assert translation["target"] == "en"
            assert translation["text"].startswith("[EN]")

    assert FakeTranslateProvider.calls >= 1


def test_disabled_translation_never_calls_provider() -> None:
    FakeTranslateProvider.reset()
    with TestClient(app) as client:
        with client.websocket_connect("/ws/asr") as websocket:
            websocket.send_json(START)
            assert websocket.receive_json()["type"] == "ready"

            websocket.send_json({"type": "configure", "translate": {"enabled": False, "target": "en"}})
            websocket.send_bytes(ONE_SECOND_PCM)
            assert websocket.receive_json()["type"] == "partial"

            websocket.send_json({"type": "flush"})
            final = websocket.receive_json()
            assert final["type"] == "final"

    assert FakeTranslateProvider.calls == 0


def test_translation_cache_roundtrip_and_eviction() -> None:
    cache = TranslationCache(maxsize=2)

    assert cache.get("你好", "en") is None
    cache.put("你好", "en", "Hello")
    assert cache.get("你好", "en") == "Hello"

    cache.put("世界", "en", "World")
    cache.put("朋友", "en", "Friend")

    assert cache.get("你好", "en") is None  # evicted as the oldest entry
    assert cache.get("世界", "en") == "World"
    assert len(cache) == 2
