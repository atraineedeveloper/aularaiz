import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static const Size minimumInteractiveSize = Size(48, 48);

  static ThemeData light(AppPalette palette) =>
      _base(Brightness.light, palette);

  static ThemeData dark(AppPalette palette) => _base(Brightness.dark, palette);

  static ThemeData highContrastLight(AppPalette palette) =>
      _base(Brightness.light, palette, contrastLevel: 1);

  static ThemeData highContrastDark(AppPalette palette) =>
      _base(Brightness.dark, palette, contrastLevel: 1);

  static ThemeData _base(
    Brightness brightness,
    AppPalette palette, {
    double contrastLevel = 0,
  }) {
    final generated = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );
    final scheme = generated.copyWith(
      primary: palette.primary,
      onPrimary: Colors.white,
      secondary: palette.secondary,
      onSecondary: Colors.white,
      tertiary: palette.tertiary,
      surfaceTint: palette.primary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      focusColor: scheme.primary.withValues(
        alpha: brightness == Brightness.dark ? 0.28 : 0.18,
      ),
    );
    final textTheme = GoogleFonts.montserratTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.montserrat(
        textStyle: base.textTheme.displayLarge,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: GoogleFonts.montserrat(
        textStyle: base.textTheme.displayMedium,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.montserrat(
        textStyle: base.textTheme.headlineLarge,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.montserrat(
        textStyle: base.textTheme.headlineMedium,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.montserrat(
        textStyle: base.textTheme.titleLarge,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.montserrat(
        textStyle: base.textTheme.titleMedium,
        fontWeight: FontWeight.w600,
      ),
      labelLarge: GoogleFonts.montserrat(
        textStyle: base.textTheme.labelLarge,
        fontWeight: FontWeight.w600,
      ),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: GoogleFonts.montserratTextTheme(base.primaryTextTheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minimumInteractiveSize,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minimumInteractiveSize,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minimumInteractiveSize,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: minimumInteractiveSize,
          padding: const EdgeInsets.all(12),
        ),
      ),
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(minimumInteractiveSize),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 28),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onSecondaryContainer),
        selectedLabelTextStyle: base.textTheme.labelLarge?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelMedium),
      ),
    );
  }
}
