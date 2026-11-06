import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures the microphone as 16 kHz / mono / 16-bit PCM.
///
/// This is the only platform-specific audio code in the app; swapping the
/// capture plugin later only requires keeping [start]/[stop] semantics.
class AudioCapture {
  AudioCapture({RecordConfig? config})
      : _config = config ??
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
              autoGain: true,
              echoCancel: true,
              noiseSuppress: true,
            );

  final RecordConfig _config;
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Stream<Uint8List>> start() async {
    final Stream<Uint8List> stream = await _recorder.startStream(_config);
    _recording = true;
    return stream;
  }

  Future<void> stop() async {
    if (!_recording) return;
    _recording = false;
    await _recorder.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}
