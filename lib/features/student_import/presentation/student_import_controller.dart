import 'package:aularaiz/application/student_import/import_students.dart';
import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/application/student_import/student_import_parser.dart';
import 'package:aularaiz/application/student_import/student_import_preview_builder.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/infrastructure/student_import/student_import_file_reader.dart';
import 'package:flutter/foundation.dart';

final class StudentImportController extends ChangeNotifier {
  StudentImportController({
    required this.group,
    required StudentImportPreviewBuilder previewBuilder,
    required ImportStudents importStudents,
    StudentImportFileReader fileReader = const StudentImportFileReader(),
    StudentImportParser parser = const StudentImportParser(),
  }) : _previewBuilder = previewBuilder,
       _importStudents = importStudents,
       _fileReader = fileReader,
       _parser = parser;

  final TeachingGroup group;
  final StudentImportPreviewBuilder _previewBuilder;
  final ImportStudents _importStudents;
  final StudentImportFileReader _fileReader;
  final StudentImportParser _parser;

  StudentImportTable? _table;
  StudentImportMapping? _mapping;
  List<StudentImportDraft> _drafts = const [];
  StudentImportPreview? _preview;
  bool _isReading = false;
  bool _isImporting = false;
  Object? _error;
  StudentImportFormatProblem? _formatProblem;

  StudentImportTable? get table => _table;
  StudentImportMapping? get mapping => _mapping;
  List<StudentImportDraft> get drafts => _drafts;
  StudentImportPreview? get preview => _preview;
  bool get isReading => _isReading;
  bool get isImporting => _isImporting;
  Object? get error => _error;
  StudentImportFormatProblem? get formatProblem => _formatProblem;

  bool get mappingHasDuplicateColumns {
    final mapping = _mapping;
    if (mapping == null) return false;
    final mapped = mapping.columns.values.whereType<int>().toList();
    return mapped.length != mapped.toSet().length;
  }

  bool get mappingReady =>
      _mapping?.hasRequiredFields == true && !mappingHasDuplicateColumns;

  Future<void> loadFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    if (_isReading || _isImporting) return;
    _isReading = true;
    _error = null;
    _formatProblem = null;
    notifyListeners();

    try {
      final table = _fileReader.read(fileName: fileName, bytes: bytes);
      final mapping = _parser.suggestMapping(table);
      _table = table;
      _mapping = mapping;
      _drafts = const [];
      _preview = null;
      if (mappingReady) {
        await _reparseAndPreview();
      }
    } on StudentImportFormatException catch (error) {
      _table = null;
      _mapping = null;
      _drafts = const [];
      _preview = null;
      _formatProblem = error.problem;
      _error = error;
    } catch (error) {
      _error = error;
    } finally {
      _isReading = false;
      notifyListeners();
    }
  }

  Future<void> setColumn(StudentImportField field, int? column) async {
    final mapping = _mapping;
    if (mapping == null || _isImporting) return;
    _mapping = mapping.withColumn(field, column);
    _error = null;
    _formatProblem = null;
    if (mappingReady) {
      await _reparseAndPreview();
    } else {
      _drafts = const [];
      _preview = null;
      notifyListeners();
    }
  }

  Future<void> updateDraft(StudentImportDraft draft) async {
    if (_isImporting) return;
    final index = _drafts.indexWhere(
      (value) => value.sourceRow == draft.sourceRow,
    );
    if (index < 0) return;
    final updated = List<StudentImportDraft>.of(_drafts);
    updated[index] = draft;
    _drafts = List<StudentImportDraft>.unmodifiable(updated);
    await _rebuildPreview();
  }

  Future<void> setIncluded(int sourceRow, bool included) async {
    if (_isImporting) return;
    final index = _drafts.indexWhere((draft) => draft.sourceRow == sourceRow);
    if (index < 0) return;
    final updated = List<StudentImportDraft>.of(_drafts);
    updated[index] = updated[index].copyWith(included: included);
    _drafts = List<StudentImportDraft>.unmodifiable(updated);
    await _rebuildPreview();
  }

  Future<StudentImportResult?> confirmImport() async {
    final table = _table;
    final preview = _preview;
    if (table == null ||
        preview == null ||
        !preview.canConfirm ||
        _isImporting) {
      return null;
    }

    _isImporting = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _importStudents(
        group: group,
        sourceName: table.sourceName,
        sheetName: table.sheetName,
        drafts: _drafts,
      );
      return result;
    } on StudentImportValidationException catch (error) {
      _preview = error.preview;
      _error = error;
      return null;
    } catch (error) {
      _error = error;
      return null;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<void> _reparseAndPreview() async {
    final table = _table;
    final mapping = _mapping;
    if (table == null || mapping == null || !mappingReady) return;
    _drafts = _parser.parseDrafts(table, mapping);
    await _rebuildPreview();
  }

  Future<void> _rebuildPreview() async {
    final table = _table;
    if (table == null) return;
    try {
      _preview = await _previewBuilder.build(
        group: group,
        sourceName: table.sourceName,
        sheetName: table.sheetName,
        drafts: _drafts,
      );
      _error = null;
    } catch (error) {
      _preview = null;
      _error = error;
    }
    notifyListeners();
  }
}
