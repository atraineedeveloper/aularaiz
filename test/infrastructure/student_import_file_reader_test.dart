import 'dart:convert';

import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/infrastructure/student_import/student_import_file_reader.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reader = StudentImportFileReader();

  test('reads semicolon CSV exported by spreadsheet software', () {
    final table = reader.read(
      fileName: 'alumnos.csv',
      bytes: utf8.encode(
        'sep=;\nN. de lista;Nombres;Apellido paterno;Grado\n'
        '1;Ana;López;5\n',
      ),
    );

    expect(table.sourceName, 'alumnos.csv');
    expect(table.sheetName, isNull);
    expect(table.rows, hasLength(2));
    expect(table.rows[0], [
      'N. de lista',
      'Nombres',
      'Apellido paterno',
      'Grado',
    ]);
    expect(table.rows[1][0].toString(), '1');
    expect(table.rows[1][1], 'Ana');
  });

  test('falls back to Latin-1 for legacy CSV files', () {
    final table = reader.read(
      fileName: 'alumnos.csv',
      bytes: latin1.encode(
        'Nombres;Apellido paterno;Grado;Lista\nJosé;Muñoz;5;2\n',
      ),
    );

    expect(table.rows[1][0], 'José');
    expect(table.rows[1][1], 'Muñoz');
  });

  test('reads XLSX values in memory and ignores formulas as import data', () {
    final workbook = Excel.createExcel();
    workbook.appendRow('Alumnos', [
      TextCellValue('Nombres'),
      TextCellValue('Primer apellido'),
      TextCellValue('Segundo apellido'),
      TextCellValue('Nacimiento'),
      TextCellValue('Grado'),
      TextCellValue('Lista'),
    ]);
    workbook.appendRow('Alumnos', [
      TextCellValue('Ana'),
      TextCellValue('López'),
      FormulaCellValue('UPPER("Perez")'),
      DateCellValue(year: 2016, month: 3, day: 12),
      IntCellValue(5),
      IntCellValue(1),
    ]);
    final bytes = workbook.encode();
    expect(bytes, isNotNull);

    final table = reader.read(fileName: 'alumnos.xlsx', bytes: bytes!);

    expect(table.sheetName, 'Alumnos');
    expect(table.rows, hasLength(2));
    expect(table.rows[1][0], 'Ana');
    expect(table.rows[1][1], 'López');
    expect(table.rows[1][2], isNull);
    expect(table.rows[1][3], DateTime(2016, 3, 12));
    expect(table.rows[1][4], 5);
    expect(table.rows[1][5], 1);
  });

  test('rejects unsupported file types before parsing', () {
    expect(
      () => reader.read(fileName: 'alumnos.pdf', bytes: const [1, 2, 3]),
      throwsA(
        isA<StudentImportFormatException>().having(
          (error) => error.problem,
          'problem',
          StudentImportFormatProblem.unsupportedFile,
        ),
      ),
    );
  });
}
