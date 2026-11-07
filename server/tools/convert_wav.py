"""Convert a mono 16-bit WAV to 16 kHz mono s16le raw PCM.

Usage: python tools/convert_wav.py <input.wav> <output.pcm>
"""

from __future__ import annotations

import sys
import wave
import audioop

TARGET_RATE = 16000


def main(src: str, dst: str) -> None:
    with wave.open(src, "rb") as wav:
        width = wav.getsampwidth()
        channels = wav.getnchannels()
        assert width == 2 and channels == 1, f"expected mono s16le, got width={width} channels={channels}"
        data = wav.readframes(wav.getnframes())
        rate = wav.getframerate()

    converted, _ = audioop.ratecv(data, 2, 1, rate, TARGET_RATE, None)
    with open(dst, "wb") as handle:
        handle.write(converted)
    seconds = len(converted) / (TARGET_RATE * 2)
    print(f"source rate={rate} -> {TARGET_RATE} Hz, {len(converted)} bytes, {seconds:.2f}s")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: python tools/convert_wav.py <in.wav> <out.pcm>")
    main(sys.argv[1], sys.argv[2])
