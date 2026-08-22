import 'dart:async';

import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  AppSettingsController._({
    required SharedPreferencesAsync preferences,
    required ThemeMode themeMode,
    required Locale locale,
    required AppPalette palette,
  }) : _preferences = preferences,
       _themeMode = themeMode,
       _locale = locale,
       _palette = palette;

  static const _localeKey = 'settings.locale';
  static const _themeModeKey = 'settings.themeMode';
  static const _paletteKey = 'settings.palette';

  final SharedPreferencesAsync? _preferences;

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('es');
  AppPalette _palette = AppPalette.government2024;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  AppPalette get palette => _palette;

  static Future<AppSettingsController> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final storage = preferences ?? SharedPreferencesAsync();
    final localeCode = await storage.getString(_localeKey);
    final themeModeName = await storage.getString(_themeModeKey);
    final paletteName = await storage.getString(_paletteKey);

    return AppSettingsController._(
      preferences: storage,
      themeMode: _themeModeFromName(themeModeName),
      locale: _localeFromCode(localeCode),
      palette: _paletteFromName(paletteName),
    );
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    _saveString(_themeModeKey, value.name);
  }

  void setLocale(Locale value) {
    final normalized = _localeFromCode(value.languageCode);
    if (_locale == normalized) return;
    _locale = normalized;
    notifyListeners();
    _saveString(_localeKey, normalized.languageCode);
  }

  void setPalette(AppPalette value) {
    if (_palette == value) return;
    _palette = value;
    notifyListeners();
    _saveString(_paletteKey, value.name);
  }

  void _saveString(String key, String value) {
    final preferences = _preferences;
    if (preferences == null) return;
    unawaited(preferences.setString(key, value));
  }

  static Locale _localeFromCode(String? value) {
    return value == 'en' ? const Locale('en') : const Locale('es');
  }

  static ThemeMode _themeModeFromName(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static AppPalette _paletteFromName(String? value) {
    return value == AppPalette.government2018.name
        ? AppPalette.government2018
        : AppPalette.government2024;
  }
}
