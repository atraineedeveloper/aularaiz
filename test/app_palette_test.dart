import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('2024 palette keeps requested government-inspired colors', () {
    expect(AppPalette.government2024.primary, const Color(0xFF9B2247));
    expect(AppPalette.government2024.secondary, const Color(0xFF1E5B4F));
    expect(AppPalette.government2024.tertiary, const Color(0xFFA57F2C));
  });

  test('2018 palette keeps requested government-inspired colors', () {
    expect(AppPalette.government2018.primary, const Color(0xFF9D2449));
    expect(AppPalette.government2018.secondary, const Color(0xFF285C4D));
    expect(AppPalette.government2018.tertiary, const Color(0xFFB38E5D));
  });
}
