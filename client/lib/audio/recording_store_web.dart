import 'dart:typed_data';

/// No-op on web: the web build uses the demo session, which never writes audio.
class RecordingStore {
  bool get isRecording => false;

  Future<void> start(String directory) async {}

  void write(Uint8List chunk) {}

  Future<String?> finalize() async => null;
}
