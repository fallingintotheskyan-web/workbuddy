import 'dart:async';
import 'dart:typed_data';

import '../audio/audio_capture.dart';
import '../models/language.dart';
import '../models/session_status.dart';
import '../net/asr_protocol.dart';
import '../net/asr_ws_client.dart';
import 'recording_session.dart';

/// Real session: microphone PCM -> WebSocket -> ASR proxy -> partial/final.
class WsRecordingSession implements RecordingSession {
  WsRecordingSession({required this.endpoint, AudioCapture? capture})
      : _capture = capture ?? AudioCapture();

  final Uri endpoint;
  final AudioCapture _capture;
  final StreamController<SessionEvent> _events = StreamController<SessionEvent>.broadcast();

  AsrWsClient? _client;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _translationEnabled = false;
  TargetLanguage _target = TargetLanguage.english;

  @override
  Stream<SessionEvent> get events => _events.stream;

  @override
  Future<void> start({required SourceLanguage source}) async {
    _emit(const StatusEvent(SessionStatus.connecting));

    final bool granted = await _capture.hasPermission();
    if (!granted) {
      _fail('麦克风权限被拒绝，请在系统设置中允许录音后重试。');
      return;
    }

    try {
      final AsrWsClient client = AsrWsClient(endpoint: endpoint);
      _client = client;
      _messageSubscription = client.messages.listen(_onServerMessage);
      await client.connect();
      client.sendJson(buildStartMessage(source: source));
      client.sendJson(buildConfigureMessage(enabled: _translationEnabled, target: _target));

      final Stream<Uint8List> audio = await _capture.start();
      _audioSubscription = audio.listen(
        client.sendAudio,
        onError: (Object error) => _fail('音频采集失败：$error'),
      );
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
  Future<void> stop() async {
    _client?.sendJson(<String, dynamic>{'type': 'stop'});
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _capture.stop();
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _client?.close();
    _client = null;
    _emit(const StatusEvent(SessionStatus.idle));
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _capture.dispose();
    await _events.close();
  }

  void _onServerMessage(Map<String, dynamic> message) {
    final SessionEvent? event = parseServerMessage(message);
    if (event == null) return;
    if (event is ErrorEvent) {
      _emit(const StatusEvent(SessionStatus.error));
    }
    _emit(event);
  }

  void _fail(String message) {
    _emit(const StatusEvent(SessionStatus.error));
    _emit(ErrorEvent(message));
  }

  void _emit(SessionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
