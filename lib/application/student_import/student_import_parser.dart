import 'dart:math' as math;

import 'package:aularaiz/application/student_import/student_import_models.dart';

final class StudentImportParser {
  const StudentImportParser();

  StudentImportMapping suggestMapping(StudentImportTable table) {
    if (table.rows.isEmpty) {
      throw const StudentImportFormatException(
        StudentImportFormatProblem.emptyFile,
      );
    }

    var bestRowIndex = -1;
    var bestScore = -1;
    var bestHeaders = const <String>[];
    var bestColumns = <StudentImportField, int?>{
      for (final field in StudentImportField.values) field: null,
    };

    final rowsToInspect = math.min(table.rows.length, 12);
    for (var rowIndex = 0; rowIndex < rowsToInspect; rowIndex++) {
      final row = table.rows[rowIndex];
      final headers = <String>[
        for (var column = 0; column < row.length; column++)
          _headerLabel(row[column], column),
      ];
      if (headers.every((header) => header.trim().isEmpty)) continue;

      final columns = <StudentImportField, int?>{
        for (final field in StudentImportField.values) field: null,
      };
      for (var column = 0; column < headers.length; column++) {
        final field = _fieldForHeader(headers[column]);
        if (field != null && columns[field] == null) {
          columns[field] = column;
        }
      }
      final score = columns.values.where((column) => column != null).length;
      if (score > bestScore) {
        bestRowIndex = rowIndex;
        bestScore = score;
        bestHeaders = headers;
        bestColumns = columns;
      }
    }

    if (bestRowIndex < 0) {
      throw const StudentImportFormatException(
        StudentImportFormatProblem.emptyFile,
      );
    }

    return StudentImportMapping(
      headerRowIndex: bestRowIndex,
      headers: bestHeaders,
      columns: bestColumns,
    );
  }

  List<StudentImportDraft> parseDrafts(
    StudentImportTable table,
    StudentImportMapping mapping,
  ) {
    if (!mapping.hasRequiredFields) {
      throw StateError('Required import columns are not mapped.');
    }

    final drafts = <StudentImportDraft>[];
    for (
      var rowIndex = mapping.headerRowIndex + 1;
      rowIndex < table.rows.length;
      rowIndex++
    ) {
      final row = table.rows[rowIndex];
      if (_isBlankRow(row)) continue;

      drafts.add(
        StudentImportDraft(
          sourceRow: rowIndex + 1,
          givenNames: _mappedText(row, mapping, StudentImportField.givenNames),
          firstSurname: _mappedText(
            row,
            mapping,
            StudentImportField.firstSurname,
          ),
          secondSurname: _mappedText(
            row,
            mapping,
            StudentImportField.secondSurname,
          ),
          sexText: _mappedText(row, mapping, StudentImportField.sex),
          birthDateText: _mappedText(
            row,
            mapping,
            StudentImportField.birthDate,
          ),
          gradeText: _mappedText(row, mapping, StudentImportField.grade),
          listNumberText: _mappedText(
            row,
            mapping,
            StudentImportField.listNumber,
          ),
        ),
      );
    }

    return List<StudentImportDraft>.unmodifiable(drafts);
  }

  String _mappedText(
    List<Object?> row,
    StudentImportMapping mapping,
    StudentImportField field,
  ) {
    final column = mapping.columnFor(field);
    if (column == null || column < 0 || column >= row.length) return '';
    return _cellText(row[column]).trim();
  }

  bool _isBlankRow(List<Object?> row) {
    return row.every((value) => _cellText(value).trim().isEmpty);
  }

  String _headerLabel(Object? value, int column) {
    final text = _cellText(value).trim();
    return text.isEmpty ? 'Columna ${column + 1}' : text;
  }

  String _cellText(Object? value) {
    if (value == null) return '';
    if (value is DateTime) {
      return '${value.year.toString().padLeft(4, '0')}-'
          '${value.month.toString().padLeft(2, '0')}-'
          '${value.day.toString().padLeft(2, '0')}';
    }
    if (value is int) return value.toString();
    if (value is double) {
      return value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString();
    }
    return value.toString().replaceFirst('\ufeff', '');
  }

  StudentImportField? _fieldForHeader(String header) {
    final normalized = _normalize(header);
    for (final entry in _aliases.entries) {
      if (entry.value.contains(normalized)) return entry.key;
    }
    return null;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp('[áàäâã]'), 'a')
        .replaceAll(RegExp('[éèëê]'), 'e')
        .replaceAll(RegExp('[íìïî]'), 'i')
        .replaceAll(RegExp('[óòöôõ]'), 'o')
        .replaceAll(RegExp('[úùüû]'), 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp('[^a-z0-9]+'), ' ')
        .trim();
  }
}

const Map<StudentImportField, Set<String>> _aliases = {
  StudentImportField.listNumber: {
    'numero de lista',
    'numero lista',
    'no de lista',
    'n de lista',
    'num lista',
    'lista',
    'list number',
    'list no',
  },
  StudentImportField.givenNames: {
    'nombres',
    'nombre',
    'nombre s',
    'given names',
    'given name',
    'first names',
  },
  StudentImportField.firstSurname: {
    'primer apellido',
    'apellido paterno',
    'paterno',
    'apellido 1',
    'first surname',
    'surname 1',
  },
  StudentImportField.secondSurname: {
    'segundo apellido',
    'apellido materno',
    'materno',
    'apellido 2',
    'second surname',
    'surname 2',
  },
  StudentImportField.sex: {
    'sexo',
    'genero',
    'sexo alumno',
    'genero alumno',
    'sex',
    'gender',
  },
  StudentImportField.birthDate: {
    'fecha de nacimiento',
    'fecha nacimiento',
    'nacimiento',
    'fecha nac',
    'birth date',
    'date of birth',
  },
  StudentImportField.grade: {'grado', 'grado escolar', 'grade', 'school grade'},
};
