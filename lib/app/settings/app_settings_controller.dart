import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  AppSettingsController._({
    required SharedPreferencesAsync preferences,
    required ThemeMode themeMode,
    required Locale locale,
  }) : _preferences = preferences,
       _themeMode = themeMode,
       _locale = locale;

  static const _localeKey = 'settings.locale';
  static const _themeModeKey = 'settings.themeMode';

  final SharedPreferencesAsync? _preferences;

  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('es');

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  static Future<AppSettingsController> load({
    SharedPreferencesAsync? preferences,
  }) async {
    final storage = preferences ?? SharedPreferencesAsync();
    final localeCode = await storage.getString(_localeKey);
    final themeModeName = await storage.getString(_themeModeKey);

    return AppSettingsController._(
      preferences: storage,
      themeMode: _themeModeFromName(themeModeName),
      locale: _localeFromCode(localeCode),
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
}
