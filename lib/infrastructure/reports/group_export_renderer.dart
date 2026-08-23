import 'dart:convert';
import 'dart:typed_data';

import 'package:aularaiz/application/reports/report_models.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

enum GroupExportFormat { csv, xlsx }

final class GroupExportRenderer {
  const GroupExportRenderer({required this.english});

  final bool english;

  Uint8List renderCsv(
    GroupReportData report, {
    required bool includeSensitiveFollowUp,
  }) {
    final rows = _rows(
      report,
      includeSensitiveFollowUp: includeSensitiveFollowUp,
      formulaSafe: true,
    );
    final encoded = const CsvEncoder(
      fieldDelimiter: ';',
      lineDelimiter: '\r\n',
      addBom: true,
    ).convert(rows);
    return Uint8List.fromList(utf8.encode(encoded));
  }

  Uint8List renderXlsx(
    GroupReportData report, {
    required bool includeSensitiveFollowUp,
  }) {
    final workbook = Excel.createExcel();
    workbook.rename('Sheet1', english ? 'Students' : 'Alumnos');
    final sheetName = english ? 'Students' : 'Alumnos';
    final rows = _rows(
      report,
      includeSensitiveFollowUp: includeSensitiveFollowUp,
      formulaSafe: false,
    );

    for (final row in rows) {
      workbook.appendRow(
        sheetName,
        row
            .map<CellValue?>((value) {
              return switch (value) {
                final int value => IntCellValue(value),
                final double value => DoubleCellValue(value),
                final String value => TextCellValue(value),
                null => null,
                _ => TextCellValue(value.toString()),
              };
            })
            .toList(growable: false),
      );
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw StateError('Could not encode XLSX group export.');
    }
    return Uint8List.fromList(bytes);
  }

  List<List<Object?>> _rows(
    GroupReportData report, {
    required bool includeSensitiveFollowUp,
    required bool formulaSafe,
  }) {
    final rows = <List<Object?>>[
      _headers(includeSensitiveFollowUp: includeSensitiveFollowUp),
    ];

    for (final student in report.students) {
      final values = <Object?>[
        student.listNumber,
        student.displayName,
        student.grade.number,
        student.attendance.present,
        student.attendance.absent,
        student.attendance.late,
        student.attendance.justifiedAbsence,
        student.evaluation.pending,
        student.evaluation.delivered,
        student.evaluation.notDelivered,
        student.evaluation.evaluated,
        student.evaluation.mastered,
        student.evaluation.sufficient,
        student.evaluation.inProgress,
        student.evaluation.requiresSupport,
      ];
      if (includeSensitiveFollowUp) {
        values.addAll([
          student.strengths ?? '',
          student.difficulties ?? '',
          student.supports ?? '',
        ]);
      }
      rows.add(
        formulaSafe
            ? values
                  .map<Object?>((value) {
                    return value is String ? _formulaSafe(value) : value;
                  })
                  .toList(growable: false)
            : values,
      );
    }

    return rows;
  }

  List<Object?> _headers({required bool includeSensitiveFollowUp}) {
    final headers = english
        ? <Object?>[
            'List number',
            'Student',
            'Grade',
            'Present',
            'Absent',
            'Late',
            'Justified absence',
            'Pending evaluations',
            'Delivered',
            'Not delivered',
            'Evaluated',
            'Mastered',
            'Sufficient',
            'In progress',
            'Requires support',
          ]
        : <Object?>[
            'N. de lista',
            'Alumno',
            'Grado',
            'Presentes',
            'Ausencias',
            'Retardos',
            'Ausencias justificadas',
            'Evaluaciones pendientes',
            'Entregadas',
            'No entregadas',
            'Evaluadas',
            'Dominado',
            'Suficiente',
            'En proceso',
            'Requiere apoyo',
          ];
    if (includeSensitiveFollowUp) {
      headers.addAll(
        english
            ? ['Strengths', 'Difficulties', 'Supports and adjustments']
            : ['Fortalezas', 'Dificultades', 'Apoyos y ajustes'],
      );
    }
    return headers;
  }

  String _formulaSafe(String value) {
    final trimmed = value.trimLeft();
    if (trimmed.isEmpty) return value;
    return switch (trimmed.codeUnitAt(0)) {
      0x3D || 0x2B || 0x2D || 0x40 => "'$value",
      _ => value,
    };
  }
}
