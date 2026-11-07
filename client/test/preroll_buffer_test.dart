import 'dart:typed_data';

import 'package:classroom_notes/audio/preroll_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('caps at the requested duration and drains in order', () {
    final PreRollBuffer buffer = PreRollBuffer(durationMs: 100); // 3200 bytes
    final Uint8List frame = Uint8List.fromList(List<int>.filled(640, 1));

    for (int i = 0; i < 8; i++) {
      buffer.add(frame);
    }

    // 8 x 640 = 5120 bytes fed, but only the last 3200 bytes are kept.
    expect(buffer.length, 3200);

    final Uint8List drained = buffer.drain();
    expect(drained.length, 3200);
    expect(buffer.length, 0);
  });

  test('drain returns an empty buffer after clear', () {
    final PreRollBuffer buffer = PreRollBuffer(durationMs: 300);
    buffer.add(Uint8List.fromList(List<int>.filled(640, 1)));
    buffer.clear();
    expect(buffer.drain().length, 0);
  });
}
