import 'package:flutter/material.dart';

enum AppPalette { government2024, government2018 }

extension AppPaletteColors on AppPalette {
  Color get primary => switch (this) {
    AppPalette.government2024 => const Color(0xFF9B2247),
    AppPalette.government2018 => const Color(0xFF9D2449),
  };

  Color get primaryDark => switch (this) {
    AppPalette.government2024 => const Color(0xFF611232),
    AppPalette.government2018 => const Color(0xFF621132),
  };

  Color get secondary => switch (this) {
    AppPalette.government2024 => const Color(0xFF1E5B4F),
    AppPalette.government2018 => const Color(0xFF285C4D),
  };

  Color get secondaryDark => switch (this) {
    AppPalette.government2024 => const Color(0xFF002F2A),
    AppPalette.government2018 => const Color(0xFF13322B),
  };

  Color get tertiary => switch (this) {
    AppPalette.government2024 => const Color(0xFFA57F2C),
    AppPalette.government2018 => const Color(0xFFB38E5D),
  };

  Color get tertiarySoft => switch (this) {
    AppPalette.government2024 => const Color(0xFFE6D194),
    AppPalette.government2018 => const Color(0xFFD4C19C),
  };

  List<Color> get swatches => <Color>[
    primary,
    primaryDark,
    secondary,
    secondaryDark,
    tertiary,
    tertiarySoft,
  ];
}
