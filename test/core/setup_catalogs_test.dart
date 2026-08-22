import 'package:aularaiz/core/catalogs/mexico_geography_catalog.dart';
import 'package:aularaiz/core/catalogs/school_year_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mexico geography catalog contains all states and Tabasco municipalities', () {
    expect(MexicoGeographyCatalog.states, hasLength(32));
    expect(
      MexicoGeographyCatalog.states.map((state) => state.code).toSet(),
      hasLength(32),
    );

    final tabasco = MexicoGeographyCatalog.byCode('27');
    expect(tabasco, isNotNull);
    expect(tabasco!.name, 'Tabasco');
    expect(tabasco.municipalities, contains('Balancán'));
    expect(tabasco.municipalities, hasLength(17));
  });

  test('current basic education preset matches SEP 2026-2027 calendar', () {
    final cycle = SchoolYearCatalog.currentBasicEducation(
      DateTime(2026, 8, 22),
    );

    expect(cycle.label, '2026-2027');
    expect(cycle.startsOn, DateTime(2026, 8, 31));
    expect(cycle.endsOn, DateTime(2027, 7, 9));
  });
}
