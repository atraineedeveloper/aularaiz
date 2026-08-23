import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/application/student_import/student_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = StudentImportParser();

  test('finds a header row and maps common Mexican school headers', () {
    final table = StudentImportTable(
      sourceName: 'lista.csv',
      rows: const [
        ['Escuela Primaria Benito Juárez'],
        ['Ciclo escolar 2026-2027'],
        [
          'N. de lista',
          'Nombres',
          'Apellido paterno',
          'Apellido materno',
          'Fecha de nacimiento',
          'Grado',
        ],
        [1, 'Ana María', 'López', 'Pérez', '12/03/2016', '5°'],
      ],
    );

    final mapping = parser.suggestMapping(table);

    expect(mapping.headerRowIndex, 2);
    expect(mapping.columnFor(StudentImportField.listNumber), 0);
    expect(mapping.columnFor(StudentImportField.givenNames), 1);
    expect(mapping.columnFor(StudentImportField.firstSurname), 2);
    expect(mapping.columnFor(StudentImportField.secondSurname), 3);
    expect(mapping.columnFor(StudentImportField.birthDate), 4);
    expect(mapping.columnFor(StudentImportField.grade), 5);
    expect(mapping.hasRequiredFields, isTrue);

    final drafts = parser.parseDrafts(table, mapping);
    expect(drafts, hasLength(1));
    expect(drafts.single.sourceRow, 4);
    expect(drafts.single.listNumberText, '1');
    expect(drafts.single.givenNames, 'Ana María');
    expect(drafts.single.firstSurname, 'López');
    expect(drafts.single.secondSurname, 'Pérez');
    expect(drafts.single.birthDateText, '12/03/2016');
    expect(drafts.single.gradeText, '5°');
  });

  test('manual mapping supports arbitrary source headers', () {
    final table = StudentImportTable(
      sourceName: 'padron.csv',
      rows: const [
        ['A', 'B', 'C', 'D'],
        ['Sofía', 'García', '3', 7],
      ],
    );
    final suggested = parser.suggestMapping(table);
    final mapping = StudentImportMapping(
      headerRowIndex: suggested.headerRowIndex,
      headers: suggested.headers,
      columns: const {
        StudentImportField.givenNames: 0,
        StudentImportField.firstSurname: 1,
        StudentImportField.secondSurname: null,
        StudentImportField.birthDate: null,
        StudentImportField.grade: 2,
        StudentImportField.listNumber: 3,
      },
    );

    final drafts = parser.parseDrafts(table, mapping);

    expect(drafts, hasLength(1));
    expect(drafts.single.givenNames, 'Sofía');
    expect(drafts.single.firstSurname, 'García');
    expect(drafts.single.gradeText, '3');
    expect(drafts.single.listNumberText, '7');
  });

  test('skips fully blank data rows and preserves native dates', () {
    final table = StudentImportTable(
      sourceName: 'alumnos.xlsx',
      rows: [
        const [
          'Nombres',
          'Primer apellido',
          'Grado',
          'Número de lista',
          'Nacimiento',
        ],
        const [null, null, null, null, null],
        ['Luis', 'Díaz', 4, 2.0, DateTime(2017, 8, 9)],
      ],
    );
    var mapping = parser.suggestMapping(table);
    mapping = mapping.withColumn(StudentImportField.birthDate, 4);

    final drafts = parser.parseDrafts(table, mapping);

    expect(drafts, hasLength(1));
    expect(drafts.single.sourceRow, 3);
    expect(drafts.single.gradeText, '4');
    expect(drafts.single.listNumberText, '2');
    expect(drafts.single.birthDateText, '2017-08-09');
  });
}
