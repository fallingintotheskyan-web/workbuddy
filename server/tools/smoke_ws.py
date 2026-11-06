"""Minimal WebSocket smoke client.

Usage (with the server running):
    python tools/smoke_ws.py [ws://127.0.0.1:8000/ws/asr]

Sends 1 second of silence as 20 ms PCM frames, asks for a finalization and
prints every server message. Exits non-zero unless a final transcript arrives.
"""

from __future__ import annotations

import asyncio
import json
import sys

import websockets

START = {
    "type": "start",
    "sourceLanguage": "zh",
    "sampleRate": 16000,
    "channels": 1,
    "encoding": "pcm_s16le",
}
FRAME = b"\x00\x00" * 320  # 20 ms @ 16 kHz mono s16le


async def main(url: str) -> int:
    async with websockets.connect(url) as websocket:
        await websocket.send(json.dumps(START))
        ready = json.loads(await websocket.recv())
        print("<-", ready)
        if ready.get("type") != "ready":
            return 2

        for _ in range(50):
            await websocket.send(FRAME)
            await asyncio.sleep(0.02)

        await websocket.send(json.dumps({"type": "flush"}))

        saw_final = False
        while True:
            raw = await asyncio.wait_for(websocket.recv(), timeout=5)
            message = json.loads(raw)
            print("<-", message)
            if message.get("type") == "final":
                saw_final = True
                break

        await websocket.send(json.dumps({"type": "stop"}))
        return 0 if saw_final else 1


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "ws://127.0.0.1:8000/ws/asr"
    raise SystemExit(asyncio.run(main(target)))
