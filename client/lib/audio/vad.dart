import 'dart:math' as math;
import 'dart:typed_data';

/// Energy-based voice activity detector.
///
/// Audio is 16 kHz / mono / s16le (32 000 bytes per second), but the capture
/// plugin delivers variable-size chunks, so all timing is computed from the
/// byte count instead of assuming a fixed frame size. This is what made silence
/// detection sluggish on real devices: a 128 ms chunk was counted as one
/// "20 ms" frame.
class VoiceActivityDetector {
  VoiceActivityDetector({
    this.minSpeechMs = 100,
    this.silenceHoldMs = 1500,
    this.initialNoiseFloor = 250.0,
  }) : _noiseFloor = initialNoiseFloor;

  final int minSpeechMs;
  final int silenceHoldMs;
  final double initialNoiseFloor;

  double _noiseFloor;
  double _speechMs = 0;
  double _silenceMs = 0;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  /// Feed one PCM chunk (16-bit little-endian mono) and return the new state.
  bool processFrame(Uint8List pcm) {
    final double rms = _rms(pcm);
    _adaptNoiseFloor(rms);

    // Track the noise floor with a margin and a floor, so normal speech trips
    // even on quiet microphones without firing on background hiss.
    final double threshold = math.max(_noiseFloor * 1.8 + 100.0, 350.0);
    final bool voiced = rms > threshold;

    // 32 000 bytes/s => 32 bytes/ms.
    final double chunkMs = pcm.length / 32.0;

    if (voiced) {
      _speechMs += chunkMs;
      _silenceMs = 0;
      if (!_speaking && _speechMs >= minSpeechMs) {
        _speaking = true;
      }
    } else {
      _silenceMs += chunkMs;
      _speechMs = 0;
      if (_speaking && _silenceMs >= silenceHoldMs) {
        _speaking = false;
      }
    }
    return _speaking;
  }

  void reset() {
    _noiseFloor = initialNoiseFloor;
    _speechMs = 0;
    _silenceMs = 0;
    _speaking = false;
  }

  void _adaptNoiseFloor(double rms) {
    if (rms < _noiseFloor) {
      // Quiet input pulls the floor down quickly so quiet speech still trips.
      _noiseFloor = _noiseFloor * 0.92 + rms * 0.08;
    } else {
      // Loud input only nudges it up, so it does not chase the speaker's voice.
      _noiseFloor = _noiseFloor * 0.995 + rms * 0.005;
    }
    if (_noiseFloor < 10.0) _noiseFloor = 10.0;
  }

  double _rms(Uint8List pcm) {
    final int samples = pcm.length ~/ 2;
    if (samples == 0) return 0.0;
    final ByteData data = ByteData.sublistView(pcm);
    double sum = 0.0;
    for (int i = 0; i < samples; i++) {
      final int sample = data.getInt16(i * 2, Endian.little);
      sum += sample * sample;
    }
    return math.sqrt(sum / samples);
  }
}
