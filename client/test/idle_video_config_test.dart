import 'package:classroom_notes/config/idle_video_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdleVideoConfig.parse', () {
    test('accepts an asset entry', () {
      final IdleVideoConfig? config =
          IdleVideoConfig.parse('{"type":"asset","value":"assets/idle/idle_loop.mp4"}');

      expect(config, isNotNull);
      expect(config!.isAsset, isTrue);
      expect(config.uri, 'asset:///assets/idle/idle_loop.mp4');
    });

    test('accepts a network URL', () {
      final IdleVideoConfig? config =
          IdleVideoConfig.parse('{"type":"url","value":"https://example.com/loop.mp4"}');

      expect(config, isNotNull);
      expect(config!.isAsset, isFalse);
      expect(config.uri, 'https://example.com/loop.mp4');
    });

    test('defaults to asset when the type is omitted', () {
      final IdleVideoConfig? config = IdleVideoConfig.parse('{"value":"assets/a.mp4"}');

      expect(config?.type, IdleVideoType.asset);
    });

    test('rejects malformed JSON, unknown types and empty values', () {
      expect(IdleVideoConfig.parse('not json'), isNull);
      expect(IdleVideoConfig.parse('{"type":"ftp","value":"x"}'), isNull);
      expect(IdleVideoConfig.parse('{"type":"asset","value":"   "}'), isNull);
    });
  });
}
