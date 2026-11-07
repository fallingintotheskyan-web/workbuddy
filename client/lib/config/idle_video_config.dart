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
  const IdleVideoConfig({
    required this.type,
    required this.value,
    this.rotation = 0,
  });

  final IdleVideoType type;
  final String value;

  /// Forced clockwise rotation in degrees: 0 / 90 / 180 / 270. Used to correct
  /// sources whose frames are stored sideways with no rotation metadata.
  final int rotation;

  int get quarterTurns => rotation ~/ 90;

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

      final IdleVideoType? videoType = switch (type) {
        'url' => IdleVideoType.url,
        'asset' || null || '' => IdleVideoType.asset,
        _ => null,
      };
      if (videoType == null) return null;

      final int rotation = _parseRotation(decoded['rotation']);

      return IdleVideoConfig(type: videoType, value: value, rotation: rotation);
    } catch (_) {
      return null;
    }
  }

  static int _parseRotation(Object? value) {
    final int parsed = switch (value) {
      int v => v,
      String s => int.tryParse(s) ?? 0,
      _ => 0,
    };
    return const <int>[0, 90, 180, 270].contains(parsed) ? parsed : 0;
  }

  bool get isAsset => type == IdleVideoType.asset;

  /// media_kit uses `asset:///` for bundled files and plain URIs for network.
  String get uri => isAsset ? 'asset:///$value' : value;

  String get description => isAsset ? '本地资源 $value' : value;

  @override
  String toString() => 'IdleVideoConfig(${type.name}, $value)';
}
