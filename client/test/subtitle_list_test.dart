import 'package:classroom_notes/core/app_theme.dart';
import 'package:classroom_notes/features/recording/widgets/subtitle_list.dart';
import 'package:classroom_notes/models/language.dart';
import 'package:classroom_notes/models/transcript_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: child),
    );
  }

  testWidgets('partial subtitle is italic and final is normal weight', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        const SubtitleList(
          lines: <TranscriptLine>[
            TranscriptLine(
              id: 's1',
              text: '最终句子',
              translation: 'Final sentence',
              translationTarget: TargetLanguage.english,
            ),
          ],
          partial: '临时字幕',
        ),
      ),
    );

    expect(find.text('最终句子'), findsOneWidget);
    expect(find.text('Final sentence'), findsOneWidget);
    expect(find.text('临时字幕'), findsOneWidget);

    final Text partial = tester.widget<Text>(
      find.byKey(const ValueKey<String>('partial-subtitle')),
    );
    expect(partial.style?.fontStyle, FontStyle.italic);

    final Text finalLine = tester.widget<Text>(find.text('最终句子'));
    expect(finalLine.style?.fontStyle, isNot(FontStyle.italic));
  });

  testWidgets('empty transcript shows the listening hint', (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(const SubtitleList(lines: <TranscriptLine>[], partial: '')),
    );

    expect(find.text('正在聆听…'), findsOneWidget);
  });
}
