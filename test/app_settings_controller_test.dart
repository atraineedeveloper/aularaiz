import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settings start in system mode and Spanish', () {
    final controller = AppSettingsController();

    expect(controller.themeMode, ThemeMode.system);
    expect(controller.locale, const Locale('es'));
  });

  test('settings update theme and locale', () {
    final controller = AppSettingsController();

    controller
      ..setThemeMode(ThemeMode.dark)
      ..setLocale(const Locale('en'));

    expect(controller.themeMode, ThemeMode.dark);
    expect(controller.locale, const Locale('en'));
  });

  test('unsupported locales fall back to Spanish', () {
    final controller = AppSettingsController();

    controller.setLocale(const Locale('fr'));

    expect(controller.locale, const Locale('es'));
  });
}
