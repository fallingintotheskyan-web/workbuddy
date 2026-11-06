from fastapi.testclient import TestClient

from app.main import app

START = {
    "type": "start",
    "sourceLanguage": "zh",
    "sampleRate": 16000,
    "channels": 1,
    "encoding": "pcm_s16le",
}
ONE_SECOND_PCM = b"\x00\x00" * 16000


def test_health() -> None:
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["sampleRate"] == 16000


def test_fake_session_emits_partial_then_final() -> None:
    with TestClient(app) as client:
        with client.websocket_connect("/ws/asr") as websocket:
            websocket.send_json(START)
            ready = websocket.receive_json()
            assert ready["type"] == "ready"
            assert ready["provider"] == "fake"
            assert ready["sampleRate"] == 16000

            websocket.send_bytes(ONE_SECOND_PCM)
            partial = websocket.receive_json()
            assert partial["type"] == "partial"
            assert partial["text"]

            websocket.send_json({"type": "flush"})
            final = websocket.receive_json()
            assert final["type"] == "final"
            assert final["text"]
            assert final["id"]


def test_rejects_wrong_sample_rate() -> None:
    with TestClient(app) as client:
        with client.websocket_connect("/ws/asr") as websocket:
            websocket.send_json({**START, "sampleRate": 8000})
            message = websocket.receive_json()

    assert message["type"] == "error"
    assert "sampleRate" in message["message"]


def test_rejects_unaligned_pcm_frame() -> None:
    with TestClient(app) as client:
        with client.websocket_connect("/ws/asr") as websocket:
            websocket.send_json(START)
            websocket.receive_json()
            websocket.send_bytes(b"\x01")
            message = websocket.receive_json()

    assert message["type"] == "error"
    assert "16-bit" in message["message"]


def test_unknown_control_message_returns_error() -> None:
    with TestClient(app) as client:
        with client.websocket_connect("/ws/asr") as websocket:
            websocket.send_json(START)
            websocket.receive_json()
            websocket.send_json({"type": "dance"})
            message = websocket.receive_json()

    assert message["type"] == "error"
    assert "dance" in message["message"]
