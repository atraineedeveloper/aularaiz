import 'package:flutter/material.dart';

enum AppPalette { mexico }

extension AppPaletteColors on AppPalette {
  Color get primary => const Color(0xFF9B2247);
  Color get primaryDark => const Color(0xFF611232);
  Color get secondary => const Color(0xFF1E5B4F);
  Color get secondaryDark => const Color(0xFF002F2A);
  Color get tertiary => const Color(0xFFA57F2C);
  Color get tertiarySoft => const Color(0xFFE6D194);

  List<Color> get swatches => <Color>[
    primary,
    primaryDark,
    secondary,
    secondaryDark,
    tertiary,
    tertiarySoft,
  ];
}
