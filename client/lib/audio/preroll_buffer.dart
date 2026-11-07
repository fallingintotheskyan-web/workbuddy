import 'dart:typed_data';

/// Rolling buffer of the most recent [durationMs] of audio.
///
/// When speech resumes after a silence gap we replay this so the ASR stream
/// stays continuous and the first syllable is not swallowed.
class PreRollBuffer {
  PreRollBuffer({required this.durationMs});

  final int durationMs;

  /// 16 kHz / mono / s16le => 32 000 bytes per second.
  late final int _maxBytes = 16000 * 2 * durationMs ~/ 1000;
  final List<Uint8List> _chunks = <Uint8List>[];
  int _bytes = 0;

  int get length => _bytes;

  void add(Uint8List chunk) {
    if (chunk.isEmpty) return;
    _chunks.add(chunk);
    _bytes += chunk.length;
    while (_bytes > _maxBytes && _chunks.isNotEmpty) {
      _bytes -= _chunks.removeAt(0).length;
    }
  }

  /// Returns everything buffered and empties the buffer.
  Uint8List drain() {
    final Uint8List output = Uint8List(_bytes);
    int offset = 0;
    for (final Uint8List chunk in _chunks) {
      output.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    _chunks.clear();
    _bytes = 0;
    return output;
  }

  void clear() {
    _chunks.clear();
    _bytes = 0;
  }
}
