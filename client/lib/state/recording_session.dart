import '../models/language.dart';
import '../models/session_status.dart';

/// Events emitted by a [RecordingSession] implementation.
///
/// Phase 2 will add a WebSocket implementation that maps the backend protocol
/// onto the same events, so the UI and controller stay unchanged.
sealed class SessionEvent {
  const SessionEvent();
}

class StatusEvent extends SessionEvent {
  const StatusEvent(this.status, {this.detail});

  final SessionStatus status;
  final String? detail;
}

class PartialEvent extends SessionEvent {
  const PartialEvent(this.text);

  final String text;
}

class FinalEvent extends SessionEvent {
  const FinalEvent(this.id, this.text);

  final String id;
  final String text;
}

class TranslationEvent extends SessionEvent {
  const TranslationEvent(this.id, this.text, this.target);

  final String id;
  final String text;
  final TargetLanguage target;
}

class ErrorEvent extends SessionEvent {
  const ErrorEvent(this.message);

  final String message;
}

/// A source of partial/final transcript events.
abstract class RecordingSession {
  Stream<SessionEvent> get events;

  /// Absolute path of the captured debug audio (first seconds sent to ASR),
  /// or null until it has been written.
  String? get debugAudioPath;

  Future<void> start({required SourceLanguage source});

  /// Stops the session and returns the absolute path of the saved recording,
  /// or null when no recording was produced.
  Future<String?> stop();

  void updateTranslation({required bool enabled, required TargetLanguage target});

  /// Switches the recognition language and re-opens the upstream stream.
  Future<void> updateSource(SourceLanguage source);

  Future<void> dispose();
}
