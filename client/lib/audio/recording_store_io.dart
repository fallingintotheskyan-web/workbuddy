import 'dart:io';
import 'dart:typed_data';

/// Native implementation of the recording store (Android / desktop).
class RecordingStore {
  static const int sampleRate = 16000;
  static const int channels = 1;
  static const int bitsPerSample = 16;

  IOSink? _sink;
  File? _pcmFile;
  String? _pcmPath;
  int _bytes = 0;
  bool _started = false;

  bool get isRecording => _started;

  Future<void> start(String directory) async {
    final Directory dir = Directory(directory);
    await dir.create(recursive: true);
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    _pcmPath = '${dir.path}${Platform.pathSeparator}rec_$timestamp.pcm';
    _pcmFile = File(_pcmPath!);
    _sink = _pcmFile!.openWrite();
    _bytes = 0;
    _started = true;
  }

  void write(Uint8List chunk) {
    if (!_started) return;
    _sink?.add(chunk);
    _bytes += chunk.length;
  }

  /// Returns the absolute path of the saved WAV, or null if nothing was recorded.
  Future<String?> finalize() async {
    if (!_started) return null;
    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    final String wavPath = _pcmPath!.replaceAll('.pcm', '.wav');
    await _pcmToWav(_pcmPath!, wavPath, _bytes);
    try {
      await _pcmFile?.delete();
    } catch (_) {
      // Best effort: leaving a temp .pcm behind is harmless.
    }
    _started = false;
    return wavPath;
  }

  Future<void> _pcmToWav(String pcmPath, String wavPath, int dataBytes) async {
    final int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final int blockAlign = channels * bitsPerSample ~/ 8;

    final ByteData header = ByteData(44);
    _writeAscii(header, 0, 'RIFF');
    header.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(header, 8, 'WAVE');
    _writeAscii(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // PCM fmt chunk size
    header.setUint16(20, 1, Endian.little); // audio format = PCM
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
