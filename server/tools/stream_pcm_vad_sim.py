"""Phase-3 protocol check: flush at a mid-stream "silence" boundary must lock the
current sentence, and a second flush must lock the rest.

Usage: python tools/stream_pcm_vad_sim.py <file.pcm> [url]
"""

from __future__ import annotations

import asyncio
import json
import sys

import websockets

FRAME = 640


async def _send_range(websocket, audio: bytes, start: int, end: int) -> None:
    # Only send complete frames; a trailing partial frame would be rejected as
    # unaligned (real mic chunks are always even-length s16le).
    for offset in range(start, end - FRAME + 1, FRAME):
        await websocket.send(audio[offset:offset + FRAME])
        await asyncio.sleep(0.004)


async def _collect_until_final(websocket, timeout: float, finals: list[str]) -> bool:
    try:
        while True:
            message = json.loads(await asyncio.wait_for(websocket.recv(), timeout=timeout))
            kind = message.get("type")
            if kind == "partial":
                print("  partial:", message.get("text", "")[:60])
            elif kind == "final":
                text = message.get("text", "")
                finals.append(text)
                print("  final  :", text[:60])
                return True
            elif kind == "error":
                print("  ERROR  :", message.get("message"))
                return False
    except asyncio.TimeoutError:
        print("  (timeout waiting for final)")
        return False


async def main(pcm_path: str, url: str) -> int:
    with open(pcm_path, "rb") as handle:
        audio = handle.read()

    midpoint = len(audio) // 2
    finals: list[str] = []

    async with websockets.connect(url) as websocket:
        await websocket.send(json.dumps({
            "type": "start",
            "sourceLanguage": "zh",
            "sampleRate": 16000,
            "channels": 1,
            "encoding": "pcm_s16le",
        }))
        print("<-", await websocket.recv())

        print("first half + flush:")
        await _send_range(websocket, audio, 0, midpoint)
        await websocket.send(json.dumps({"type": "flush"}))
        first_ok = await _collect_until_final(websocket, 6, finals)

        print("second half + flush:")
        await _send_range(websocket, audio, midpoint, len(audio))
        await websocket.send(json.dumps({"type": "flush"}))
        second_ok = await _collect_until_final(websocket, 6, finals)

        await websocket.send(json.dumps({"type": "stop"}))

    print("FINALS:", finals)
    return 0 if first_ok and second_ok else 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("usage: python tools/stream_pcm_vad_sim.py <file.pcm> [url]")
    target = sys.argv[2] if len(sys.argv) > 2 else "ws://127.0.0.1:8000/ws/asr"
    raise SystemExit(asyncio.run(main(sys.argv[1], target)))
