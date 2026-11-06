import 'dart:convert';

import 'package:flutter/services.dart';

enum IdleVideoType { asset, url }

/// Describes what to play on the idle screen.
///
/// `config/idle_video.json` supports:
/// ```json
/// { "type": "asset", "value": "assets/idle/idle_loop.mp4" }
/// { "type": "url",   "value": "https://example.com/loop.mp4" }
/// ```
class IdleVideoConfig {
  const IdleVideoConfig({required this.type, required this.value});

  final IdleVideoType type;
  final String value;

  static const IdleVideoConfig fallback = IdleVideoConfig(
    type: IdleVideoType.asset,
    value: 'assets/idle/idle_loop.mp4',
  );

  static Future<IdleVideoConfig> load() async {
    try {
      final String raw = await rootBundle.loadString('config/idle_video.json');
      return parse(raw) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Returns null when the JSON is malformed or the value is empty, so callers
  /// can fall back without crashing the idle screen.
  static IdleVideoConfig? parse(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final String? value = (decoded['value'] as String?)?.trim();
      if (value == null || value.isEmpty) return null;
      final String? type = (decoded['type'] as String?)?.trim().toLowerCase();

      return switch (type) {
        'url' => IdleVideoConfig(type: IdleVideoType.url, value: value),
        'asset' || null || '' => IdleVideoConfig(type: IdleVideoType.asset, value: value),
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  bool get isAsset => type == IdleVideoType.asset;

  /// media_kit uses `asset:///` for bundled files and plain URIs for network.
  String get uri => isAsset ? 'asset:///$value' : value;

  String get description => isAsset ? '本地资源 $value' : value;

  @override
  String toString() => 'IdleVideoConfig(${type.name}, $value)';
}
