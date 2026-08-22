import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:flutter/material.dart';

class AppSettingsController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('es');
  AppPalette _palette = AppPalette.government2024;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  AppPalette get palette => _palette;

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
  }

  void setLocale(Locale value) {
    final normalized = value.languageCode == 'en'
        ? const Locale('en')
        : const Locale('es');
    if (_locale == normalized) return;
    _locale = normalized;
    notifyListeners();
  }

  void setPalette(AppPalette value) {
    if (_palette == value) return;
    _palette = value;
    notifyListeners();
  }
}
