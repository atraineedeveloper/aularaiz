import 'package:flutter/material.dart';

/// AulaRaíz product colors.
///
/// The palette is intentionally product-owned and carries no institutional,
/// political or administration label in the user experience.
abstract final class AppPalette {
  static const Color primary = Color(0xFF9B2247);
  static const Color primaryDark = Color(0xFF611232);
  static const Color secondary = Color(0xFF1E5B4F);
  static const Color secondaryDark = Color(0xFF002F2A);
  static const Color tertiary = Color(0xFFA57F2C);
  static const Color tertiarySoft = Color(0xFFE6D194);

  static const List<Color> swatches = <Color>[
    primary,
    primaryDark,
    secondary,
    secondaryDark,
    tertiary,
    tertiarySoft,
  ];
}
