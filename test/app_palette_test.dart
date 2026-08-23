import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AulaRaíz keeps its single product palette', () {
    expect(AppPalette.values, <AppPalette>[AppPalette.mexico]);
    expect(AppPalette.mexico.primary, const Color(0xFF9B2247));
    expect(AppPalette.mexico.secondary, const Color(0xFF1E5B4F));
    expect(AppPalette.mexico.tertiary, const Color(0xFFA57F2C));
  });
}
