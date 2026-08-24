import 'dart:convert';

import 'package:aularaiz/application/reports/group_export_models.dart';
import 'package:aularaiz/infrastructure/reports/group_export_renderer.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GroupExportData buildData({required bool sensitive}) {
    return GroupExportData(
      context: GroupExportContextData(
        schoolName: 'Primaria de Prueba',
        cct: '27DPR0000X',
        state: 'Tabasco',
        municipality: 'Centro',
        locality: 'Villahermosa',
        schoolOrganization: 'complete',
        schoolYearLabel: '2026-2027',
        groupName: '5° A',
        shift: 'Matutino',
        grades: const [5],
        isMultigrade: false,
        phases: const ['phase5'],
        startsAtMinutes: 480,
        endsAtMinutes: 780,
        referenceMonth: DateTime(2026, 8),
      ),
      students: [
        GroupExportStudentRow(
          studentId: 'student-1',
          displayName: '=HYPERLINK("https://example.com")',
          givenNames: 'Ana',
          firstSurname: 'Pérez',
          secondSurname: 'López',
          sex: 'female',
          birthDate: DateTime(2015, 4, 3),
          age: 11,
          listNumber: 7,
          grade: 5,
          enrollmentStartsOn: DateTime(2026, 8, 1),
          isActive: true,
          strengths: sensitive ? '+SUM(1,1)' : null,
          difficulties: sensitive ? '@cmd' : null,
          supports: sensitive ? '-1+2' : null,
        ),
      ],
      attendance: [
        GroupExportAttendanceRow(
          date: DateTime(2026, 8, 24),
          studentId: 'student-1',
          listNumber: 7,
          studentName: 'Ana Pérez López',
          grade: 5,
          status: 'present',
        ),
      ],
      projects: const [
        GroupExportProjectRow(
          projectId: 'project-1',
          title: 'Mi comunidad',
          lifecycle: 'inProgress',
          methodology: 'communityProjects',
          targetGrades: [5],
          articulatingAxes: ['criticalThinking', 'inclusion'],
        ),
      ],
      activities: [
        GroupExportActivityRow(
          projectId: 'project-1',
          projectTitle: 'Mi comunidad',
          activityId: 'activity-1',
          identifier: 'A-001',
          title: 'Mapa comunitario',
          occursOn: DateTime(2026, 8, 20),
          formativeField: 'humanAndCommunity',
          targetGrades: const [5],
          participantCount: 1,
        ),
      ],
      evaluations: [
        GroupExportEvaluationRow(
          projectId: 'project-1',
          projectTitle: 'Mi comunidad',
          activityId: 'activity-1',
          activityIdentifier: 'A-001',
          activityTitle: 'Mapa comunitario',
          activityDate: DateTime(2026, 8, 20),
          studentId: 'student-1',
          listNumber: 7,
          studentName: 'Ana Pérez López',
          grade: 5,
          resultState: 'deliveredAndEvaluated',
          deliveryStatus: 'delivered',
          achievement: 'mastered',
          observation: sensitive ? '=danger' : null,
        ),
      ],
      followUp: sensitive
          ? [
              GroupExportFollowUpRow(
                studentId: 'student-1',
                listNumber: 7,
                studentName: 'Ana Pérez López',
                grade: 5,
                kind: 'observation',
                occurredAt: DateTime.utc(2026, 8, 21),
                text: '@follow-up',
              ),
            ]
          : const [],
      includeSensitiveFollowUp: sensitive,
    );
  }

  test(
    'CSV exports one selected dataset and neutralizes formula-like text',
    () {
      const renderer = GroupExportRenderer(english: false);
      final bytes = renderer.renderCsv(
        buildData(sensitive: false),
        dataset: GroupExportDataset.students,
      );
      final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
      final rows = const CsvDecoder().convert(text);

      expect(rows, hasLength(2));
      expect(rows.first, containsAll(['N. de lista', 'Alumno', 'Sexo']));
      expect(rows.first, isNot(contains('Fortalezas')));
      expect(rows[1][0], '7');
      expect(rows[1][1], "'=HYPERLINK(\"https://example.com\")");
      expect(rows[1][8], 'Femenino');
    },
  );

  test('CSV exposes sensitive columns only after explicit opt-in', () {
    const renderer = GroupExportRenderer(english: false);
    final bytes = renderer.renderCsv(
      buildData(sensitive: true),
      dataset: GroupExportDataset.students,
    );
    final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
    final rows = const CsvDecoder().convert(text);

    expect(
      rows.first,
      containsAll(['Fortalezas', 'Dificultades', 'Apoyos y ajustes']),
    );
    expect(rows[1][12], "'+SUM(1,1)");
    expect(rows[1][13], "'@cmd");
    expect(rows[1][14], "'-1+2");
  });

  test('XLSX contains all teacher-facing datasets as separate sheets', () {
    const renderer = GroupExportRenderer(english: false);
    final bytes = renderer.renderXlsx(buildData(sensitive: true));
    final workbook = Excel.decodeBytes(bytes);

    expect(
      workbook.tables.keys,
      containsAll([
        'Contexto',
        'Alumnos',
        'Asistencia',
        'Proyectos',
        'Actividades',
        'Evaluacion',
        'Seguimiento',
      ]),
    );
    expect(workbook.tables['Contexto']!.rows.length, greaterThan(10));
    expect(workbook.tables['Asistencia']!.rows, hasLength(2));
    expect(workbook.tables['Proyectos']!.rows, hasLength(2));
    expect(workbook.tables['Actividades']!.rows, hasLength(2));
    expect(workbook.tables['Evaluacion']!.rows, hasLength(2));
    expect(workbook.tables['Seguimiento']!.rows, hasLength(2));
  });

  test('XLSX stores formula-looking user input as text cells', () {
    const renderer = GroupExportRenderer(english: true);
    final bytes = renderer.renderXlsx(buildData(sensitive: true));
    final workbook = Excel.decodeBytes(bytes);
    final sheet = workbook.tables['Students'];

    expect(sheet, isNotNull);
    expect(sheet!.rows, hasLength(2));
    expect(sheet.rows[1][0]!.value, isA<IntCellValue>());
    expect(sheet.rows[1][1]!.value, isA<TextCellValue>());
    expect(
      (sheet.rows[1][1]!.value as TextCellValue).value.text,
      '=HYPERLINK("https://example.com")',
    );
    expect(sheet.rows[1][12]!.value, isA<TextCellValue>());
    expect((sheet.rows[1][12]!.value as TextCellValue).value.text, '+SUM(1,1)');
  });
}
