import 'package:flutter/foundation.dart';

import '../models/language.dart';
import '../models/session_status.dart';
import '../models/transcript_line.dart';
import 'recording_session.dart';

/// Holds the transcript and UI settings for one recording session.
///
/// Partial text is kept separate from finalized lines so the view can style it
/// as "in progress" and replace it in place without touching committed lines.
class TranscriptController extends ChangeNotifier {
  final List<TranscriptLine> _lines = <TranscriptLine>[];
  String _partial = '';
  SessionStatus _status = SessionStatus.idle;
  bool _translateEnabled = false;
  TargetLanguage _target = TargetLanguage.english;
  SourceLanguage _source = SourceLanguage.chinese;
  String? _error;

  List<TranscriptLine> get lines => List<TranscriptLine>.unmodifiable(_lines);
  String get partial => _partial;
  SessionStatus get status => _status;
  bool get translateEnabled => _translateEnabled;
  TargetLanguage get target => _target;
  SourceLanguage get source => _source;
  String? get error => _error;

  void apply(SessionEvent event) {
    switch (event) {
      case StatusEvent(:final SessionStatus status):
        _status = status;
      case PartialEvent(:final String text):
        if (text == _partial) return;
        _partial = text;
      case FinalEvent(:final String id, :final String text):
        final String cleaned = text.trim();
        if (cleaned.isEmpty) return;
        if (_lines.any((TranscriptLine line) => line.id == id)) return;
        _lines.add(TranscriptLine(id: id, text: cleaned));
        _partial = '';
      case TranslationEvent(:final String id, :final String text, :final TargetLanguage target):
        final int index = _lines.indexWhere((TranscriptLine line) => line.id == id);
        if (index < 0) return;
        _lines[index] = _lines[index].copyWith(
          translation: text,
          translationTarget: target,
        );
      case ErrorEvent(:final String message):
        _error = message;
        _status = SessionStatus.error;
    }
    notifyListeners();
  }

  void setTranslateEnabled(bool enabled) {
    if (_translateEnabled == enabled) return;
    _translateEnabled = enabled;
    notifyListeners();
  }

  void setTarget(TargetLanguage target) {
    if (_target == target) return;
    _target = target;
    notifyListeners();
  }

  void setSource(SourceLanguage source) {
    if (_source == source) return;
    _source = source;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }
}
