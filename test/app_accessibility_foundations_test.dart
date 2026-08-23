import 'package:aularaiz/app/accessibility/app_accessibility_frame.dart';
import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:aularaiz/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accessible theme foundations', () {
    test('interactive controls keep at least 48 by 48 logical pixels', () {
      final theme = AppTheme.light(AppPalette.government2024);
      const emptyStates = <WidgetState>{};

      final sizes = <Size?>[
        theme.filledButtonTheme.style?.minimumSize?.resolve(emptyStates),
        theme.outlinedButtonTheme.style?.minimumSize?.resolve(emptyStates),
        theme.textButtonTheme.style?.minimumSize?.resolve(emptyStates),
        theme.iconButtonTheme.style?.minimumSize?.resolve(emptyStates),
        theme.segmentedButtonTheme.style?.minimumSize?.resolve(emptyStates),
      ];

      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      for (final size in sizes) {
        expect(size, isNotNull);
        expect(size!.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    test('focused fields use a clear two-pixel primary outline', () {
      final theme = AppTheme.light(AppPalette.government2024);
      final focused = theme.inputDecorationTheme.focusedBorder;

      expect(focused, isA<OutlineInputBorder>());
      final outline = focused! as OutlineInputBorder;
      expect(outline.borderSide.width, 2);
      expect(outline.borderSide.color, theme.colorScheme.primary);
    });

    test('light, dark and high-contrast themes preserve readable pairs', () {
      final themes = <ThemeData>[
        AppTheme.light(AppPalette.government2024),
        AppTheme.dark(AppPalette.government2024),
        AppTheme.highContrastLight(AppPalette.government2024),
        AppTheme.highContrastDark(AppPalette.government2024),
      ];

      for (final theme in themes) {
        final scheme = theme.colorScheme;
        expect(
          _contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(scheme.secondary, scheme.onSecondary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(scheme.surface, scheme.onSurface),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('global keyboard navigation', () {
    testWidgets('Ctrl+, opens settings action', (tester) async {
      var settingsCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AppAccessibilityFrame(
            onOpenSettings: () => settingsCalls += 1,
            onNavigateBack: () {},
            child: const Scaffold(body: Text('AulaRaíz')),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.comma);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(settingsCalls, 1);
    });

    testWidgets('Alt+Left invokes back navigation action', (tester) async {
      var backCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AppAccessibilityFrame(
            onOpenSettings: () {},
            onNavigateBack: () => backCalls += 1,
            child: const Scaffold(body: Text('AulaRaíz')),
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

      expect(backCalls, 1);
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
