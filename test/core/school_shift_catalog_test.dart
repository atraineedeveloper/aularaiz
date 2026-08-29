import 'package:aularaiz/core/catalogs/school_shift_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the SEP basic education shift catalog', () {
    expect(SchoolShiftCatalog.officialValues, [
      'Matutino',
      'Vespertino',
      'Nocturno',
      'Discontinuo',
      'Continuo',
    ]);
  });

  test('normalizes official values and preserves legacy values', () {
    expect(SchoolShiftCatalog.normalizeForSelection(' matutino '), 'Matutino');
    expect(
      SchoolShiftCatalog.normalizeForSelection('Jornada ampliada'),
      'Jornada ampliada',
    );
    expect(SchoolShiftCatalog.persistenceValue(''), isNull);
  });
}
