import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AulaRaiz palette keeps the requested product colors', () {
    expect(AppPalette.primary, const Color(0xFF9B2247));
    expect(AppPalette.secondary, const Color(0xFF1E5B4F));
    expect(AppPalette.tertiary, const Color(0xFFA57F2C));
    expect(AppPalette.swatches, hasLength(6));
  });
}
