import 'dart:convert';

import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/student/student_sex.dart';
import 'package:aularaiz/infrastructure/reports/group_export_renderer.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GroupReportData report;

  setUp(() {
    report = GroupReportData(
      header: ReportHeader(
        schoolName: 'Primaria de Prueba',
        schoolYearLabel: '2026-2027',
        groupName: '5° A',
        referenceMonth: DateTime(2026, 8),
      ),
      students: const [
        StudentReportRow(
          studentId: 'student-1',
          displayName: '=HYPERLINK("https://example.com")',
          listNumber: 7,
          grade: PrimaryGrade.fifth,
          sex: StudentSex.female,
          attendance: AttendanceReportSummary(
            present: 12,
            absent: 1,
            late: 2,
            justifiedAbsence: 1,
          ),
          evaluation: EvaluationReportSummary(
            pending: 1,
            delivered: 4,
            notDelivered: 1,
            evaluated: 4,
            mastered: 1,
            sufficient: 1,
            inProgress: 1,
            requiresSupport: 1,
          ),
          strengths: '+SUM(1,1)',
          difficulties: '@cmd',
          supports: '-1+2',
        ),
      ],
    );
  });

  test(
    'CSV neutralizes formula-like user text and exports sex without sensitive follow-up',
    () {
      const renderer = GroupExportRenderer(english: false);
      final bytes = renderer.renderCsv(report, includeSensitiveFollowUp: false);
      final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
      final rows = const CsvDecoder(fieldDelimiter: ';').convert(text);

      expect(rows, hasLength(2));
      expect(rows.first, hasLength(16));
      expect(rows.first, contains('Sexo'));
      expect(rows.first, isNot(contains('Fortalezas')));
      expect(rows[1][0], '7');
      expect(rows[1][1], "'=HYPERLINK(\"https://example.com\")");
      expect(rows[1][2], 'Femenino');
    },
  );

  test('CSV includes sensitive columns only after explicit opt-in', () {
    const renderer = GroupExportRenderer(english: false);
    final bytes = renderer.renderCsv(report, includeSensitiveFollowUp: true);
    final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
    final rows = const CsvDecoder(fieldDelimiter: ';').convert(text);

    expect(rows.first, hasLength(19));
    expect(
      rows.first,
      containsAll(['Fortalezas', 'Dificultades', 'Apoyos y ajustes']),
    );
    expect(rows[1][16], "'+SUM(1,1)");
    expect(rows[1][17], "'@cmd");
    expect(rows[1][18], "'-1+2");
  });

  test('XLSX stores formula-looking user input and sex as text cells', () {
    const renderer = GroupExportRenderer(english: true);
    final bytes = renderer.renderXlsx(report, includeSensitiveFollowUp: true);
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables['Students'];

    expect(sheet, isNotNull);
    expect(sheet!.rows, hasLength(2));
    expect(sheet.rows.first, hasLength(19));
    expect(sheet.rows[1][0]!.value, isA<IntCellValue>());
    expect(sheet.rows[1][1]!.value, isA<TextCellValue>());
    expect(
      (sheet.rows[1][1]!.value as TextCellValue).value.text,
      '=HYPERLINK("https://example.com")',
    );
    expect(sheet.rows[1][2]!.value, isA<TextCellValue>());
    expect((sheet.rows[1][2]!.value as TextCellValue).value.text, 'Female');
    expect(sheet.rows[1][16]!.value, isA<TextCellValue>());
    expect((sheet.rows[1][16]!.value as TextCellValue).value.text, '+SUM(1,1)');
  });
}
