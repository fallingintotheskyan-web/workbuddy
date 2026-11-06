import 'package:classroom_notes/models/language.dart';
import 'package:classroom_notes/state/recording_session.dart';
import 'package:classroom_notes/state/transcript_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranscriptController', () {
    test('partial replaces itself in place and never becomes a line', () {
      final TranscriptController controller = TranscriptController();

      controller.apply(const PartialEvent('你'));
      controller.apply(const PartialEvent('你好'));

      expect(controller.partial, '你好');
      expect(controller.lines, isEmpty);
    });

    test('final commits the sentence and clears the partial', () {
      final TranscriptController controller = TranscriptController();

      controller.apply(const PartialEvent('你好世'));
      controller.apply(const FinalEvent('s1', '你好世界'));

      expect(controller.partial, isEmpty);
      expect(controller.lines, hasLength(1));
      expect(controller.lines.single.text, '你好世界');
    });

    test('duplicate final ids are ignored (reconnect replay safety)', () {
      final TranscriptController controller = TranscriptController();

      controller.apply(const FinalEvent('s1', '你好世界'));
      controller.apply(const FinalEvent('s1', '你好世界'));

      expect(controller.lines, hasLength(1));
    });

    test('translation attaches to its sentence with the requested target', () {
      final TranscriptController controller = TranscriptController();

      controller.apply(const FinalEvent('s1', '你好'));
      controller.apply(
        const TranslationEvent('s1', 'Hello', TargetLanguage.english),
      );

      expect(controller.lines.single.translation, 'Hello');
      expect(controller.lines.single.translationTarget, TargetLanguage.english);
      expect(controller.partial, isEmpty);
    });

    test('unknown translation targets are dropped instead of crashing', () {
      final TranscriptController controller = TranscriptController();

      controller.apply(const TranslationEvent('missing', 'Hello', TargetLanguage.english));

      expect(controller.lines, isEmpty);
    });
  });
}
