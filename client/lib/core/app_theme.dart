import 'package:flutter/material.dart';

/// Dark, low-distraction theme tuned for a video background and long reading.
abstract final class AppTheme {
  static const Color accent = Color(0xFF4DD0C4);
  static const Color danger = Color(0xFFE5484D);
  static const Color background = Color(0xFF05090B);
  static const Color surface = Color(0xFF101A1F);

  static ThemeData get dark {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamilyFallback: const <String>[
        'Microsoft YaHei',
        'PingFang SC',
        'Noto Sans CJK SC',
        'Noto Sans SC',
        'sans-serif',
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
