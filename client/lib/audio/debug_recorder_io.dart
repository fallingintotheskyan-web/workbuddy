import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Captures the exact bytes we send to the ASR WebSocket (first [maxSeconds])
/// and writes them to a WAV file so the audio can be listened to.
class DebugRecorder {
  DebugRecorder({this.maxSeconds = 5});

  final int maxSeconds;

  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitsPerSample = 16;

  int get _maxBytes => sampleRate * channels * (bitsPerSample ~/ 8) * maxSeconds;

  IOSink? _sink;
  File? _pcmFile;
  String? _pcmPath;
  String? _wavPath;
  int _bytes = 0;
  bool _active = false;

  bool get isActive => _active;
  String? get wavPath => _wavPath;

  Future<void> start(String directory) async {
    final Directory dir = Directory(directory);
    await dir.create(recursive: true);
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    _pcmPath = '${dir.path}${Platform.pathSeparator}debug_$timestamp.pcm';
    _wavPath = '${dir.path}${Platform.pathSeparator}debug_$timestamp.wav';
    _pcmFile = File(_pcmPath!);
    _sink = _pcmFile!.openWrite();
    _bytes = 0;
    _active = true;
  }

  /// Append bytes that were just sent to the WebSocket.
  void write(Uint8List chunk) {
    if (!_active) return;
    final int remaining = _maxBytes - _bytes;
    if (remaining <= 0) return;
    final Uint8List data =
        chunk.length <= remaining ? chunk : Uint8List.sublistView(chunk, 0, remaining);
    _sink?.add(data);
    _bytes += data.length;
    if (_bytes >= _maxBytes) {
      unawaited(_finish());
    }
  }

  Future<String?> finish() async {
    if (_active) await _finish();
    return _wavPath;
  }

  Future<void> _finish() async {
    if (!_active) return;
    _active = false;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    await _pcmToWav(_pcmPath!, _wavPath!, _bytes);
    try {
      await _pcmFile?.delete();
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> _pcmToWav(String pcmPath, String wavPath, int dataBytes) async {
    final int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final int blockAlign = channels * bitsPerSample ~/ 8;

    final ByteData header = ByteData(44);
    _writeAscii(header, 0, 'RIFF');
    header.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(header, 8, 'WAVE');
    _writeAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    _writeAscii(header, 36, 'data');
    header.setUint32(40, dataBytes, Endian.little);

    final IOSink wav = File(wavPath).openWrite();
    wav.add(header.buffer.asUint8List());
    await for (final List<int> chunk in File(pcmPath).openRead()) {
      wav.add(chunk);
    }
    await wav.flush();
    await wav.close();
  }

  void _writeAscii(ByteData data, int offset, String text) {
    for (int i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }
}
