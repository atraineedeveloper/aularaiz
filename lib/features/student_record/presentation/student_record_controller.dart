import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/student_record/add_student_record_entry.dart';
import 'package:aularaiz/application/student_record/save_student_record.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:flutter/foundation.dart';

final class StudentRecordController extends ChangeNotifier {
  StudentRecordController({
    required StudentRecordRepository recordRepository,
    required EvaluationRepository evaluationRepository,
    required SaveStudentRecord saveStudentRecord,
    required AddStudentRecordEntry addStudentRecordEntry,
  }) : _recordRepository = recordRepository,
       _evaluationRepository = evaluationRepository,
       _saveStudentRecord = saveStudentRecord,
       _addStudentRecordEntry = addStudentRecordEntry;

  final StudentRecordRepository _recordRepository;
  final EvaluationRepository _evaluationRepository;
  final SaveStudentRecord _saveStudentRecord;
  final AddStudentRecordEntry _addStudentRecordEntry;

  Student? _student;
  StudentRecord? _record;
  List<StudentRecordEntry> _entries = const [];
  List<ActivityEvaluation> _evaluations = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  Student? get student => _student;
  StudentRecord? get record => _record;
  List<StudentRecordEntry> get entries => _entries;
  List<ActivityEvaluation> get evaluations => _evaluations;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;

  int get totalEvidence => _evaluations.length;
  int get masteredEvidence => _evaluations
      .where((evaluation) => evaluation.achievement == AchievementLevel.mastered)
      .length;
  int get requiresSupportEvidence => _evaluations
      .where(
        (evaluation) =>
            evaluation.achievement == AchievementLevel.requiresSupport,
      )
      .length;

  Future<void> load(Student student) async {
    _student = student;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _record =
          await _recordRepository.load(student.id) ??
          StudentRecord(studentId: student.id);
      _entries = await _recordRepository.listEntries(student.id);
      _evaluations = await _evaluationRepository.listForStudent(student.id);
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    required String strengths,
    required String difficulties,
    required String supports,
  }) async {
    final student = _student;
    if (student == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      final record = StudentRecord(
        studentId: student.id,
        strengths: strengths,
        difficulties: difficulties,
        supports: supports,
      );
      await _saveStudentRecord(record);
      _record = record;
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> addEntry({
    required StudentRecordEntryKind kind,
    required String text,
  }) async {
    final student = _student;
    if (student == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _addStudentRecordEntry(
        studentId: student.id,
        kind: kind,
        occurredAt: DateTime.now(),
        text: text,
      );
      _entries = await _recordRepository.listEntries(student.id);
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
