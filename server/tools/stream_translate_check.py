"""End-to-end translation check: stream a PCM file, enable translation and print
the final sentence together with its translation.

Usage: python tools/stream_translate_check.py <file.pcm> [url]
"""

from __future__ import annotations

import asyncio
import json
import sys

import websockets

FRAME = 640


async def main(pcm_path: str, url: str) -> int:
    with open(pcm_path, "rb") as handle:
        audio = handle.read()

    finals: list[str] = []
    translations: list[str] = []

    async with websockets.connect(url) as websocket:
        await websocket.send(json.dumps({
            "type": "start",
            "sourceLanguage": "zh",
            "sampleRate": 16000,
            "channels": 1,
            "encoding": "pcm_s16le",
        }))
        print("<-", await websocket.recv())

        await websocket.send(json.dumps({
            "type": "configure",
            "translate": {"enabled": True, "target": "en"},
        }))

        for offset in range(0, len(audio) - FRAME + 1, FRAME):
            await websocket.send(audio[offset:offset + FRAME])
            await asyncio.sleep(0.004)

        await websocket.send(json.dumps({"type": "flush"}))

        try:
            while True:
                message = json.loads(await asyncio.wait_for(websocket.recv(), timeout=15))
                kind = message.get("type")
                if kind == "partial":
                    print("  partial    :", message.get("text", "")[:50])
                elif kind == "final":
                    finals.append(message.get("text", ""))
                    print("  final      :", message.get("text", "")[:50])
                elif kind == "translation":
                    translations.append(message.get("text", ""))
                    print("  translation:", message.get("text", "")[:80])
                    break
                elif kind == "error":
                    print("  ERROR      :", message.get("message"))
                    return 1
        except asyncio.TimeoutError:
            pass

        await websocket.send(json.dumps({"type": "stop"}))

    print("FINALS:", finals)
    print("TRANSLATIONS:", translations)
    return 0 if translations else 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("usage: python tools/stream_translate_check.py <file.pcm> [url]")
    target = sys.argv[2] if len(sys.argv) > 2 else "ws://127.0.0.1:8000/ws/asr"
    raise SystemExit(asyncio.run(main(sys.argv[1], target)))
