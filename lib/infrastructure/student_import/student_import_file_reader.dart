import 'dart:convert';

import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

final class StudentImportFileReader {
  const StudentImportFileReader();

  StudentImportTable read({
    required String fileName,
    required List<int> bytes,
  }) {
    final lowerName = fileName.toLowerCase();
    try {
      if (lowerName.endsWith('.csv')) {
        return _readCsv(fileName: fileName, bytes: bytes);
      }
      if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xlsm')) {
        return _readXlsx(fileName: fileName, bytes: bytes);
      }
      throw const StudentImportFormatException(
        StudentImportFormatProblem.unsupportedFile,
      );
    } on StudentImportFormatException catch (error) {
      SafeLog.operationFailure(
        'parse_student_import',
        error,
        code: error.problem.name,
      );
      rethrow;
    } catch (error) {
      const formatError = StudentImportFormatException(
        StudentImportFormatProblem.unreadableFile,
      );
      SafeLog.operationFailure(
        'parse_student_import',
        error,
        code: formatError.problem.name,
      );
      throw formatError;
    }
  }

  StudentImportTable _readCsv({
    required String fileName,
    required List<int> bytes,
  }) {
    if (bytes.isEmpty) {
      throw const StudentImportFormatException(
        StudentImportFormatProblem.emptyFile,
      );
    }

    late final String contents;
    try {
      contents = utf8.decode(bytes);
    } on FormatException {
      contents = latin1.decode(bytes);
    }

    final decoded = csv.decode(contents);
    final rows = <List<Object?>>[
      for (final row in decoded) List<Object?>.from(row),
    ];
    if (_allRowsBlank(rows)) {
      throw const StudentImportFormatException(
        StudentImportFormatProblem.emptyFile,
      );
    }

    return StudentImportTable(sourceName: fileName, rows: rows);
  }

  StudentImportTable _readXlsx({
    required String fileName,
    required List<int> bytes,
  }) {
    if (bytes.isEmpty) {
      throw const StudentImportFormatException(
        StudentImportFormatProblem.emptyFile,
      );
    }

    final workbook = Excel.decodeBytes(bytes);
    for (final entry in workbook.tables.entries) {
      final rows = <List<Object?>>[
        for (final row in entry.value.rows)
          [for (final cell in row) _excelValue(cell?.value)],
      ];
      if (!_allRowsBlank(rows)) {
        return StudentImportTable(
          sourceName: fileName,
          sheetName: entry.key,
          rows: rows,
        );
      }
    }

    throw const StudentImportFormatException(
      StudentImportFormatProblem.noUsableSheet,
    );
  }

  Object? _excelValue(CellValue? value) {
    return switch (value) {
      null => null,
      TextCellValue() => _textSpanValue(value.value),
      IntCellValue() => value.value,
      DoubleCellValue() => value.value,
      BoolCellValue() => value.value,
      DateCellValue() => value.asDateTimeLocal(),
      DateTimeCellValue() => value.asDateTimeLocal(),
      FormulaCellValue() => null,
      TimeCellValue() => null,
    };
  }

  String _textSpanValue(TextSpan span) {
    final buffer = StringBuffer();
    void append(TextSpan value) {
      final text = value.text;
      if (text != null) buffer.write(text);
      final children = value.children;
      if (children != null) {
        for (final child in children) {
          append(child);
        }
      }
    }

    append(span);
    return buffer.toString();
  }

  bool _allRowsBlank(List<List<Object?>> rows) {
    return rows.every(
      (row) => row.every(
        (value) => value == null || value.toString().trim().isEmpty,
      ),
    );
  }
}
