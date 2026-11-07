"""Stream a raw 16 kHz s16le PCM file through the ASR WebSocket and print results.

Usage: python tools/stream_pcm_file.py <file.pcm> [ws://127.0.0.1:8000/ws/asr]
"""

from __future__ import annotations

import asyncio
import json
import sys

import websockets

FRAME = 640  # 20 ms @ 16 kHz mono s16le


async def main(pcm_path: str, url: str) -> int:
    with open(pcm_path, "rb") as handle:
        audio = handle.read()

    async with websockets.connect(url) as websocket:
        await websocket.send(json.dumps({
            "type": "start",
            "sourceLanguage": "zh",
            "sampleRate": 16000,
            "channels": 1,
            "encoding": "pcm_s16le",
        }))
        print("<-", await websocket.recv())

        for offset in range(0, len(audio), FRAME):
            await websocket.send(audio[offset:offset + FRAME])
            await asyncio.sleep(0.01)

        await websocket.send(json.dumps({"type": "flush"}))

        finals: list[str] = []
        partials: list[str] = []
        try:
            while True:
                message = json.loads(await asyncio.wait_for(websocket.recv(), timeout=10))
                kind = message.get("type")
                if kind == "partial":
                    partials.append(message.get("text", ""))
                    print("<- partial:", message.get("text", "")[:60])
                elif kind == "final":
                    finals.append(message.get("text", ""))
                    print("<- final  :", message.get("text", "")[:60])
                elif kind == "error":
                    print("<- ERROR  :", message.get("message"))
                    return 1
        except asyncio.TimeoutError:
            pass

        await websocket.send(json.dumps({"type": "stop"}))
        print("FINALS:", finals)
        import pathlib

        pathlib.Path("last_result.json").write_text(
            json.dumps({"finals": finals, "partials": partials}, ensure_ascii=False),
            encoding="utf-8",
        )
        return 0 if finals else 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("usage: python tools/stream_pcm_file.py <file.pcm> [url]")
    target = sys.argv[2] if len(sys.argv) > 2 else "ws://127.0.0.1:8000/ws/asr"
    raise SystemExit(asyncio.run(main(sys.argv[1], target)))
