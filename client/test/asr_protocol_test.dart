import 'package:classroom_notes/models/language.dart';
import 'package:classroom_notes/models/session_status.dart';
import 'package:classroom_notes/net/asr_protocol.dart';
import 'package:classroom_notes/state/recording_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildStartMessage', () {
    test('declares the fixed 16 kHz mono s16le contract', () {
      final Map<String, dynamic> message = buildStartMessage(source: SourceLanguage.chinese);

      expect(message['type'], 'start');
      expect(message['sourceLanguage'], 'zh');
      expect(message['sampleRate'], 16000);
      expect(message['channels'], 1);
      expect(message['encoding'], 'pcm_s16le');
    });

    test('passes auto through so the server can pick its fallback', () {
      expect(buildStartMessage(source: SourceLanguage.auto)['sourceLanguage'], 'auto');
    });
  });

  group('parseServerMessage', () {
    test('ready means listening', () {
      final SessionEvent? event = parseServerMessage(<String, dynamic>{'type': 'ready'});

      expect(event, isA<StatusEvent>());
      expect((event! as StatusEvent).status, SessionStatus.listening);
    });

    test('partial and final carry text', () {
      expect(parseServerMessage(<String, dynamic>{'type': 'partial', 'text': '你好'}),
          isA<PartialEvent>());
      final FinalEvent finalEvent = parseServerMessage(
        <String, dynamic>{'type': 'final', 'id': 's1', 'text': '你好世界'},
      )! as FinalEvent;
      expect(finalEvent.id, 's1');
      expect(finalEvent.text, '你好世界');
    });

    test('translation maps its target language', () {
      final TranslationEvent event = parseServerMessage(<String, dynamic>{
        'type': 'translation',
        'id': 's1',
        'text': 'Hello',
        'target': 'en',
      })! as TranslationEvent;

      expect(event.target, TargetLanguage.english);
      expect(event.text, 'Hello');
    });

    test('error exposes the server detail', () {
      final ErrorEvent event = parseServerMessage(
        <String, dynamic>{'type': 'error', 'message': 'boom'},
      )! as ErrorEvent;

      expect(event.message, 'boom');
    });

    test('unknown or malformed messages are ignored', () {
      expect(parseServerMessage(<String, dynamic>{'type': 'future-feature'}), isNull);
      expect(parseServerMessage(<String, dynamic>{'type': 'final', 'id': 1}), isNull);
      expect(parseServerMessage(<String, dynamic>{'type': 'partial', 'text': '   '}), isNull);
    });
  });

  group('buildConfigureMessage', () {
    test('sends the DeepL-style target code', () {
      final Map<String, dynamic> message =
          buildConfigureMessage(enabled: true, target: TargetLanguage.russian);
      final Map<String, dynamic> translate = message['translate'] as Map<String, dynamic>;

      expect(translate['enabled'], isTrue);
      expect(translate['target'], 'ru');
    });
  });
}
