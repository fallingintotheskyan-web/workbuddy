import 'dart:math' as math;
import 'dart:typed_data';

/// Energy-based voice activity detector over 20 ms frames.
///
/// The noise floor adapts slowly so it works in rooms whose background level
/// drifts. Speech must stay above the threshold for [minSpeechMs] to start, and
/// silence must last [silenceHoldMs] to stop — the hangover avoids chopping
/// sentences at short pauses.
class VoiceActivityDetector {
  VoiceActivityDetector({
    this.frameMs = 20,
    this.silenceHoldMs = 1500,
    this.minSpeechMs = 120,
    this.initialNoiseFloor = 400.0,
  }) : _noiseFloor = initialNoiseFloor;

  final int frameMs;
  final int silenceHoldMs;
  final int minSpeechMs;
  final double initialNoiseFloor;

  double _noiseFloor;
  int _voicedFrames = 0;
  int _silentFrames = 0;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  /// Feed one PCM frame (16-bit little-endian mono) and return the new state.
  bool processFrame(Uint8List pcm) {
    final double rms = _rms(pcm);
    _adaptNoiseFloor(rms);

    // Room for a meaningful dynamic range without triggering on tiny noise.
    final double threshold = _noiseFloor * 2.0 + 150.0;
    final bool voiced = rms > threshold;

    if (voiced) {
      _voicedFrames++;
      _silentFrames = 0;
      if (!_speaking && _voicedFrames * frameMs >= minSpeechMs) {
        _speaking = true;
      }
    } else {
      _silentFrames++;
      _voicedFrames = 0;
      if (_speaking && _silentFrames * frameMs >= silenceHoldMs) {
        _speaking = false;
      }
    }
    return _speaking;
  }

  void reset() {
    _noiseFloor = initialNoiseFloor;
    _voicedFrames = 0;
    _silentFrames = 0;
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
