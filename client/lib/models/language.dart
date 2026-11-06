/// Languages involved in a session.
///
/// [SourceLanguage] drives the ASR request. [TargetLanguage] drives translation
/// and is sent with each final sentence so that switching it only affects
/// sentences finalized afterwards.
enum SourceLanguage {
  auto('auto', '自动'),
  chinese('zh', '中文'),
  english('en', '英文'),
  russian('ru', '俄语');

  const SourceLanguage(this.code, this.label);

  final String code;
  final String label;
}

enum TargetLanguage {
  chinese('ZH', '中文', '中'),
  english('EN', '英文', 'EN'),
  russian('RU', '俄语', 'RU');

  const TargetLanguage(this.deeplCode, this.label, this.shortLabel);

  /// Language code understood by DeepL's `target_lang` parameter.
  final String deeplCode;
  final String label;
  final String shortLabel;
}
