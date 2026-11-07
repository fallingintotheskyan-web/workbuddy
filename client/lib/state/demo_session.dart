import 'dart:async';

import '../models/language.dart';
import '../models/session_status.dart';
import 'recording_session.dart';

/// Phase 1 stand-in for the real ASR pipeline.
///
/// It emits the same partial/final/translation events the WebSocket session
/// will emit in phase 2, which lets the whole recording UI be exercised today.
class DemoRecordingSession implements RecordingSession {
  final StreamController<SessionEvent> _events = StreamController<SessionEvent>.broadcast();

  static const List<String> _sentences = <String>[
    '今天我们讨论神经网络的基本结构。',
    'The gradient descent algorithm updates weights step by step.',
    'Обратное распространение ошибки — ключевая идея обучения.',
    '课堂笔记要记录重点概念、公式和例子。',
  ];

  bool _running = false;
  bool _translationEnabled = false;
  TargetLanguage _target = TargetLanguage.english;
  int _sequence = 0;

  @override
  Stream<SessionEvent> get events => _events.stream;

  @override
  Future<void> start({required SourceLanguage source}) async {
    if (_running) return;
    _running = true;
    _emit(const StatusEvent(SessionStatus.connecting));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!_running) return;
    _emit(const StatusEvent(SessionStatus.listening));
    unawaited(_runLoop());
  }

  Future<void> _runLoop() async {
    int index = 0;
    while (_running) {
      final String sentence = _sentences[index % _sentences.length];
      index++;

      final List<int> runes = sentence.runes.toList();
      for (int end = 2; end <= runes.length; end += 3) {
        if (!_running) return;
        _emit(PartialEvent(String.fromCharCodes(runes.take(end))));
        await Future<void>.delayed(const Duration(milliseconds: 240));
      }
      if (!_running) return;

      final String id = 'demo-${_sequence++}';
      _emit(FinalEvent(id, sentence));

      if (_translationEnabled) {
        final TargetLanguage target = _target;
        await Future<void>.delayed(const Duration(milliseconds: 420));
        if (!_running) return;
        _emit(TranslationEvent(id, '[演示译文·${target.label}] $sentence', target));
      }
      await Future<void>.delayed(const Duration(milliseconds: 850));
    }
  }

  @override
  Future<String?> stop() async {
    if (!_running) return null;
    _running = false;
    _emit(const StatusEvent(SessionStatus.idle));
    return null;
  }

  @override
  void updateTranslation({required bool enabled, required TargetLanguage target}) {
    _translationEnabled = enabled;
    _target = target;
  }

  @override
  Future<void> dispose() async {
    _running = false;
    await _events.close();
  }

  void _emit(SessionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}
