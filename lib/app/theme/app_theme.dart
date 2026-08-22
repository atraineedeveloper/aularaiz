import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF2F6B4F);

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData get highContrastLight =>
      _base(Brightness.light, contrastLevel: 1);

  static ThemeData get highContrastDark =>
      _base(Brightness.dark, contrastLevel: 1);

  static ThemeData _base(Brightness brightness, {double contrastLevel = 0}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
