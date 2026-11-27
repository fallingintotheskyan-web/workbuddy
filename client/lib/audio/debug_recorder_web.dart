import 'dart:typed_data';

/// No-op on web (debug recording is native-only).
class DebugRecorder {
  DebugRecorder({this.maxSeconds = 5});

  final int maxSeconds;

  bool get isActive => false;
  String? get wavPath => null;

  Future<void> start(String directory) async {}

  void write(Uint8List chunk) {}

  Future<String?> finish() async => null;
}
