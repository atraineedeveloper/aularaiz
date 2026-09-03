import 'dart:convert';

import 'package:aularaiz/application/reports/group_export_models.dart';
import 'package:aularaiz/infrastructure/reports/group_export_renderer.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GroupExportData buildData({
    required bool sensitive,
    bool authorities = false,
  }) {
    return GroupExportData(
      context: GroupExportContextData(
        schoolName: 'Primaria de Prueba',
        cct: '27DPR0000X',
        state: 'Tabasco',
        municipality: 'Centro',
        locality: 'Villahermosa',
        schoolZone: authorities ? 'Zona 045' : null,
        schoolSector: authorities ? 'Sector 12' : null,
        supervisorName: authorities ? 'Jorge Villalobos' : null,
        leadershipName: authorities ? 'María Pérez López' : null,
        leadershipRole: authorities ? 'teacherWithLeadership' : null,
        teacherName: authorities ? 'María Pérez López' : null,
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
      projects: [
        GroupExportProjectRow(
          projectId: 'project-1',
          title: 'Mi comunidad',
          description: 'Investigar necesidades del entorno.',
          startsOn: DateTime(2026, 8, 10),
          endsOn: DateTime(2026, 9, 15),
          observations: 'Coordinar una salida de campo.',
          lifecycle: 'inProgress',
          methodology: 'communityProjects',
          targetGrades: const [5],
          articulatingAxes: const ['criticalThinking', 'inclusion'],
        ),
      ],
      activities: [
        GroupExportActivityRow(
          projectId: 'project-1',
          projectTitle: 'Mi comunidad',
          activityId: 'activity-1',
          identifier: 'A-001',
          title: 'Mapa comunitario',
          description: 'Identificar espacios y necesidades del entorno.',
          occursOn: DateTime(2026, 8, 20),
          generalObservations: 'Trabajar por equipos de cuatro.',
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

  test('CSV context dataset includes zone, sector and school authorities', () {
    const renderer = GroupExportRenderer(english: false);
    final bytes = renderer.renderCsv(
      buildData(sensitive: false, authorities: true),
      dataset: GroupExportDataset.context,
    );
    final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
    final rows = const CsvDecoder().convert(text);

    final byField = <String, String>{
      for (final row in rows.skip(1))
        if (row.length >= 2) row[0].toString(): row[1].toString(),
    };
    expect(byField['Zona escolar'], 'Zona 045');
    expect(byField['Sector escolar'], 'Sector 12');
    expect(byField['Supervisor(a) escolar'], 'Jorge Villalobos');
    expect(byField['Responsable de dirección'], 'María Pérez López');
    expect(
      byField['Función de dirección'],
      'Docente con funciones de dirección',
    );
    expect(byField['Docente del grupo'], 'María Pérez López');
  });

  test('CSV context dataset leaves authority fields empty when missing', () {
    const renderer = GroupExportRenderer(english: false);
    final bytes = renderer.renderCsv(
      buildData(sensitive: false, authorities: false),
      dataset: GroupExportDataset.context,
    );
    final text = utf8.decode(bytes).replaceFirst('\ufeff', '');
    final rows = const CsvDecoder().convert(text);

    final byField = <String, String>{
      for (final row in rows.skip(1))
        if (row.length >= 2) row[0].toString(): row[1].toString(),
    };
    expect(byField['Zona escolar'], '');
    expect(byField['Sector escolar'], '');
    expect(byField['Supervisor(a) escolar'], '');
    expect(byField['Responsable de dirección'], '');
    expect(byField['Función de dirección'], '');
    expect(byField['Docente del grupo'], '');
  });

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

  test('CSV projects and activities include richer planning fields', () {
    const renderer = GroupExportRenderer(english: false);

    final projectText = utf8
        .decode(
          renderer.renderCsv(
            buildData(sensitive: false),
            dataset: GroupExportDataset.projects,
          ),
        )
        .replaceFirst('\ufeff', '');
    final projectRows = const CsvDecoder().convert(projectText);
    expect(
      projectRows.first,
      containsAll([
        'Descripción',
        'Fecha de inicio',
        'Fecha de fin',
        'Observaciones',
      ]),
    );
    expect(projectRows[1], contains('Investigar necesidades del entorno.'));
    expect(projectRows[1], contains('2026-08-10'));
    expect(projectRows[1], contains('2026-09-15'));

    final activityText = utf8
        .decode(
          renderer.renderCsv(
            buildData(sensitive: false),
            dataset: GroupExportDataset.activities,
          ),
        )
        .replaceFirst('\ufeff', '');
    final activityRows = const CsvDecoder().convert(activityText);
    expect(
      activityRows.first,
      containsAll(['Descripción / instrucciones', 'Observaciones generales']),
    );
    expect(
      activityRows[1],
      contains('Identificar espacios y necesidades del entorno.'),
    );
    expect(activityRows[1], contains('Trabajar por equipos de cuatro.'));
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
