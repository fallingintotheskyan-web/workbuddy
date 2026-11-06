import '../models/language.dart';
import '../models/session_status.dart';
import '../state/recording_session.dart';

/// Wire protocol between the Flutter client and the FastAPI ASR proxy.
///
/// Keeping (de)serialization in one pure-Dart file makes it testable without
/// plugins, sockets or a device.
const int kSampleRate = 16000;
const int kChannels = 1;
const String kEncoding = 'pcm_s16le';

Map<String, dynamic> buildStartMessage({required SourceLanguage source}) {
  return <String, dynamic>{
    'type': 'start',
    'sourceLanguage': source.code,
    'sampleRate': kSampleRate,
    'channels': kChannels,
    'encoding': kEncoding,
  };
}

Map<String, dynamic> buildConfigureMessage({
  required bool enabled,
  required TargetLanguage target,
}) {
  return <String, dynamic>{
    'type': 'configure',
    'translate': <String, dynamic>{
      'enabled': enabled,
      'target': target.deeplCode.toLowerCase(),
    },
  };
}

/// Maps a server JSON message to a [SessionEvent]. Unknown or incomplete
/// messages return null so a protocol addition never crashes the UI.
SessionEvent? parseServerMessage(Map<String, dynamic> message) {
  switch (message['type']) {
    case 'ready':
      return const StatusEvent(SessionStatus.listening);
    case 'partial':
      final Object? text = message['text'];
      if (text is! String || text.trim().isEmpty) return null;
      return PartialEvent(text);
    case 'final':
      final Object? id = message['id'];
      final Object? text = message['text'];
      if (id is! String || text is! String || text.trim().isEmpty) return null;
      return FinalEvent(id, text);
    case 'translation':
      final Object? id = message['id'];
      final Object? text = message['text'];
      final Object? target = message['target'];
      if (id is! String || text is! String || target is! String) return null;
      return TranslationEvent(id, text, _targetFromCode(target));
    case 'status':
      return StatusEvent(_statusFromCode(message['state']));
    case 'error':
      final Object? detail = message['message'];
      return ErrorEvent(detail is String && detail.isNotEmpty ? detail : '后端返回未知错误');
    default:
      return null;
  }
}

TargetLanguage _targetFromCode(String code) {
  final String normalized = code.toLowerCase();
  return TargetLanguage.values.firstWhere(
    (TargetLanguage language) => language.deeplCode.toLowerCase() == normalized,
    orElse: () => TargetLanguage.english,
  );
}

SessionStatus _statusFromCode(Object? code) {
  return switch (code) {
    'listening' => SessionStatus.listening,
    'paused' => SessionStatus.paused,
    'reconnecting' => SessionStatus.reconnecting,
    'error' => SessionStatus.error,
    _ => SessionStatus.listening,
  };
}
