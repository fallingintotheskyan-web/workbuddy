import 'dart:typed_data';

import 'package:classroom_notes/audio/vad.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _frame(int amplitude, {int samples = 320}) {
  final ByteData data = ByteData(samples * 2);
  for (int i = 0; i < samples; i++) {
    data.setInt16(i * 2, amplitude, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  test('quiet frames never trigger speech', () {
    final VoiceActivityDetector vad = VoiceActivityDetector();
    for (int i = 0; i < 20; i++) {
      expect(vad.processFrame(_frame(0)), isFalse);
    }
  });

  test('loud frames trigger speech after the minimum duration', () {
    final VoiceActivityDetector vad = VoiceActivityDetector(minSpeechMs: 60);
    for (int i = 0; i < 3; i++) {
      vad.processFrame(_frame(3000));
    }
    expect(vad.isSpeaking, isTrue);
  });

  test('hangover keeps speech alive across a brief pause', () {
    final VoiceActivityDetector vad =
        VoiceActivityDetector(minSpeechMs: 60, silenceHoldMs: 200);
    for (int i = 0; i < 4; i++) {
      vad.processFrame(_frame(3000));
    }
    expect(vad.isSpeaking, isTrue);

    // 60 ms of silence is shorter than the 200 ms hold.
    for (int i = 0; i < 3; i++) {
      vad.processFrame(_frame(0));
    }
    expect(vad.isSpeaking, isTrue);

    // Enough silence to drop the hangover.
    for (int i = 0; i < 10; i++) {
      vad.processFrame(_frame(0));
    }
    expect(vad.isSpeaking, isFalse);
  });

  test('reset clears the speaking state', () {
    final VoiceActivityDetector vad = VoiceActivityDetector(minSpeechMs: 60);
    for (int i = 0; i < 4; i++) {
      vad.processFrame(_frame(3000));
    }
    expect(vad.isSpeaking, isTrue);

    vad.reset();
    expect(vad.isSpeaking, isFalse);
  });

  test('large chunks are timed by bytes, not by a fixed 20 ms frame', () {
    final VoiceActivityDetector vad =
        VoiceActivityDetector(minSpeechMs: 100, silenceHoldMs: 400);

    // One 128 ms (4096-byte) loud chunk must be enough speech to start.
    vad.processFrame(_frame(3000, samples: 2048));
    expect(vad.isSpeaking, isTrue);

    // Four 128 ms silence chunks (512 ms total) must drop the hangover.
    for (int i = 0; i < 4; i++) {
      vad.processFrame(_frame(0, samples: 2048));
    }
    expect(vad.isSpeaking, isFalse);
  });
}
