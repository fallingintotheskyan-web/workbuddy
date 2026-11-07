import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/audio_capture.dart';
import '../audio/preroll_buffer.dart';
import '../audio/recording_store.dart';
import '../audio/vad.dart';
import '../models/language.dart';
import '../models/session_status.dart';
import '../net/asr_protocol.dart';
import '../net/asr_ws_client.dart';
import 'recording_session.dart';

/// Real session: microphone PCM -> WebSocket -> ASR proxy -> partial/final.
///
/// - VAD stops sending during ~1.5 s of silence and sends `flush` to lock the
///   current sentence;
/// - a 300 ms pre-roll buffer is replayed when speech resumes (and after the
///   socket connects) so the first syllable is not swallowed;
/// - transport drops trigger exponential-backoff reconnects;
/// - the raw microphone stream is written to a WAV file in the app sandbox and
///   returned on [stop].
class WsRecordingSession implements RecordingSession {
  WsRecordingSession({
    required this.endpoint,
    AudioCapture? capture,
    VoiceActivityDetector? vad,
    this.maxReconnectAttempts = 5,
  })  : _capture = capture ?? AudioCapture(),
        _vad = vad ?? VoiceActivityDetector();

  final Uri endpoint;
  final int maxReconnectAttempts;
  final AudioCapture _capture;
  final VoiceActivityDetector _vad;
  final PreRollBuffer _prebuffer = PreRollBuffer(durationMs: 300);
  final RecordingStore _store = RecordingStore();
  final StreamController<SessionEvent> _events = StreamController<SessionEvent>.broadcast();

  AsrWsClient? _client;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  Timer? _reconnectTimer;

  bool _running = false;
  bool _wasSpeaking = false;
  bool _pausedBySilence = false;
  int _reconnectAttempts = 0;
  bool _reconnecting = false;
  bool _translationEnabled = false;
  TargetLanguage _target = TargetLanguage.english;
  SourceLanguage _source = SourceLanguage.auto;
  int _capturedBytes = 0;
  int _sentBytes = 0;

  @override
  Stream<SessionEvent> get events => _events.stream;

  @override
  Future<void> start({required SourceLanguage source}) async {
    _source = source;
    _running = true;
    _wasSpeaking = false;
    _pausedBySilence = false;
    _reconnectAttempts = 0;
    _reconnecting = false;
    _capturedBytes = 0;
    _sentBytes = 0;
    _vad.reset();
    _prebuffer.clear();
    _emit(const StatusEvent(SessionStatus.connecting));

    final bool granted = await _capture.hasPermission();
    if (!granted) {
      _fail('麦克风权限被拒绝，请在系统设置中允许录音后重试。');
      return;
    }

    // Recording is best-effort; it must never block live transcription.
    try {
      final docs = await getApplicationDocumentsDirectory();
      await _store.start('${docs.path}/recordings');
    } catch (error) {
      debugPrint('recording store init failed: $error');
    }

    try {
      // Start capture first and buffer it, so no audio is lost while the
      // socket connects. The buffered audio is replayed once connected.
      final Stream<Uint8List> audio = await _capture.start();
      _audioSubscription = audio.listen(
        _onAudio,
        onError: (Object error) => _fail('音频采集失败：$error'),
      );

      await _connect();
      final Uint8List pre = _prebuffer.drain();
      if (pre.isNotEmpty && _client != null) {
        _sentBytes += pre.length;
        _client!.sendAudio(pre);
      }
      _emit(const StatusEvent(SessionStatus.listening));
    } catch (error) {
      _fail('无法连接识别服务（$endpoint）：$error');
    }
  }

  @override
  void updateTranslation({required bool enabled, required TargetLanguage target}) {
    _translationEnabled = enabled;
    _target = target;
    _client?.sendJson(buildConfigureMessage(enabled: enabled, target: target));
  }

  @override
  Future<String?> stop() async {
    if (!_running) return null;
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _client?.sendJson(const <String, dynamic>{'type': 'stop'});
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _capture.stop();
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _client?.close();
    _client = null;

    final String? savedPath = await _store.finalize();

    final double capturedSeconds = _capturedBytes / 32000;
    final double sentSeconds = _sentBytes / 32000;
    debugPrint(
      'session metrics: captured=${capturedSeconds.toStringAsFixed(1)}s '
      'asrSent=${sentSeconds.toStringAsFixed(1)}s',
    );

    _emit(const StatusEvent(SessionStatus.idle));
    return savedPath;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _capture.dispose();
    await _events.close();
  }

  Future<void> _connect() async {
    final AsrWsClient client = AsrWsClient(endpoint: endpoint);
    await client.connect();
    _client = client;
    await _messageSubscription?.cancel();
    _messageSubscription = client.messages.listen(_onServerMessage);
    client.sendJson(buildStartMessage(source: _source));
    client.sendJson(buildConfigureMessage(enabled: _translationEnabled, target: _target));
    _reconnectAttempts = 0;
    _reconnecting = false;
  }

  void _onAudio(Uint8List chunk) {
    _capturedBytes += chunk.length;
    _store.write(chunk);

    final AsrWsClient? client = _client;
    if (client == null) {
      // Transport is down and reconnect is in flight; keep a little audio.
      _prebuffer.add(chunk);
      return;
    }

    final bool speaking = _vad.processFrame(chunk);

    if (speaking) {
      if (_pausedBySilence) {
        _pausedBySilence = false;
        _emit(const StatusEvent(SessionStatus.listening));
        final Uint8List pre = _prebuffer.drain();
        if (pre.isNotEmpty) {
          _sentBytes += pre.length;
          client.sendAudio(pre);
        }
      }
      _sentBytes += chunk.length;
      client.sendAudio(chunk);
      _prebuffer.add(chunk);
    } else {
      _prebuffer.add(chunk);
      if (_wasSpeaking) {
        _pausedBySilence = true;
        client.sendJson(const <String, dynamic>{'type': 'flush'});
        _emit(const StatusEvent(SessionStatus.paused));
      }
    }
    _wasSpeaking = speaking;
  }

  void _onServerMessage(Map<String, dynamic> message) {
    if (message['type'] == '__closed') {
      _onDisconnected();
      return;
    }
    final SessionEvent? event = parseServerMessage(message);
    if (event == null) return;
    if (event is ErrorEvent) {
      _emit(const StatusEvent(SessionStatus.error));
    }
    _emit(event);
  }

  void _onDisconnected() {
    final AsrWsClient? old = _client;
    _client = null;
    unawaited(_messageSubscription?.cancel());
    _messageSubscription = null;
    unawaited(old?.close());
    if (!_running) return;
    _emit(const StatusEvent(SessionStatus.reconnecting));
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnecting || !_running) return;
    _reconnecting = true;
    _reconnectAttempts++;
    final int seconds = math.min(1 << (_reconnectAttempts - 1), 8);
    _reconnectTimer = Timer(Duration(seconds: seconds), () async {
      try {
        await _connect();
        final Uint8List pre = _prebuffer.drain();
        if (pre.isNotEmpty && _client != null) {
          _sentBytes += pre.length;
          _client!.sendAudio(pre);
        }
        _emit(StatusEvent(_vad.isSpeaking ? SessionStatus.listening : SessionStatus.paused));
      } catch (_) {
        _reconnecting = false;
        if (_reconnectAttempts >= maxReconnectAttempts) {
          _fail('网络不稳，多次重连失败。请检查后端是否运行。');
        } else {
          _scheduleReconnect();
        }
      }
    });
  }

  void _fail(String message) {
    _emit(const StatusEvent(SessionStatus.error));
    _emit(ErrorEvent(message));
  }

  void _emit(SessionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
