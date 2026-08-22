import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings start in system mode, Spanish and current palette', () {
    final controller = AppSettingsController();

    expect(controller.themeMode, ThemeMode.system);
    expect(controller.locale, const Locale('es'));
    expect(controller.palette, AppPalette.government2024);
  });

  test('settings update theme, locale and palette', () {
    final controller = AppSettingsController();

    controller
      ..setThemeMode(ThemeMode.dark)
      ..setLocale(const Locale('en'))
      ..setPalette(AppPalette.government2018);

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.locale, const Locale('en'));
    expect(controller.palette, AppPalette.government2018);
  });

  test('unsupported locales fall back to Spanish', () {
    final controller = AppSettingsController();

    controller.setLocale(const Locale('fr'));

    expect(controller.locale, const Locale('es'));
  });
}
