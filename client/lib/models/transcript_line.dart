import 'language.dart';

/// One finalized sentence. Translations are attached asynchronously and are
/// always rendered under the original text.
class TranscriptLine {
  const TranscriptLine({
    required this.id,
    required this.text,
    this.translation,
    this.translationTarget,
  });

  final String id;
  final String text;
  final String? translation;
  final TargetLanguage? translationTarget;

  TranscriptLine copyWith({
    String? text,
    String? translation,
    TargetLanguage? translationTarget,
  }) {
    return TranscriptLine(
      id: id,
      text: text ?? this.text,
      translation: translation ?? this.translation,
      translationTarget: translationTarget ?? this.translationTarget,
    );
  }
}
