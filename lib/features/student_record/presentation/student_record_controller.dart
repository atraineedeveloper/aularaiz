import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/student_record/add_student_record_entry.dart';
import 'package:aularaiz/application/student_record/update_student_record.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:flutter/foundation.dart';

export 'package:aularaiz/features/student_record/presentation/student_record_localization.dart';

final class AttendanceEvidence {
  const AttendanceEvidence({required this.date, required this.status});

  final DateTime date;
  final AttendanceStatus status;
}

final class EvaluationEvidence {
  const EvaluationEvidence({
    required this.activityTitle,
    required this.evaluation,
  });

  final String activityTitle;
  final ActivityEvaluation evaluation;
}

final class StudentRecordController extends ChangeNotifier {
  StudentRecordController({
    required StudentRecordRepository studentRecordRepository,
    required AttendanceRepository attendanceRepository,
    required EvaluationRepository evaluationRepository,
    required ActivityRepository activityRepository,
    required UpdateStudentRecord updateStudentRecord,
    required AddStudentRecordEntry addStudentRecordEntry,
  }) : _studentRecordRepository = studentRecordRepository,
       _attendanceRepository = attendanceRepository,
       _evaluationRepository = evaluationRepository,
       _activityRepository = activityRepository,
       _updateStudentRecord = updateStudentRecord,
       _addStudentRecordEntry = addStudentRecordEntry;

  final StudentRecordRepository _studentRecordRepository;
  final AttendanceRepository _attendanceRepository;
  final EvaluationRepository _evaluationRepository;
  final ActivityRepository _activityRepository;
  final UpdateStudentRecord _updateStudentRecord;
  final AddStudentRecordEntry _addStudentRecordEntry;

  TeachingGroup? _group;
  Student? _student;
  StudentRecord? _record;
  List<StudentRecordEntry> _entries = const [];
  List<AttendanceEvidence> _attendanceEvidence = const [];
  List<EvaluationEvidence> _evaluationEvidence = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  TeachingGroup? get group => _group;
  Student? get student => _student;
  StudentRecord? get record => _record;
  List<StudentRecordEntry> get entries => _entries;
  List<AttendanceEvidence> get attendanceEvidence => _attendanceEvidence;
  List<EvaluationEvidence> get evaluationEvidence => _evaluationEvidence;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;

  int attendanceCount(AttendanceStatus status) {
    return _attendanceEvidence
        .where((evidence) => evidence.status == status)
        .length;
  }

  Future<void> load({
    required TeachingGroup group,
    required Student student,
    DateTime? referenceDate,
  }) async {
    _group = group;
    _student = student;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final reference = referenceDate ?? DateTime.now();
      _record = await _studentRecordRepository.find(student.id);
      _entries = await _studentRecordRepository.listEntries(student.id);

      final attendance = await _attendanceRepository.listForMonth(
        group.id,
        reference,
      );
      final attendanceEvidence = <AttendanceEvidence>[];
      for (final day in attendance) {
        final status = day.statusFor(student.id);
        if (status == null) continue;
        attendanceEvidence.add(
          AttendanceEvidence(date: day.date, status: status),
        );
      }
      attendanceEvidence.sort((left, right) => right.date.compareTo(left.date));
      _attendanceEvidence = List<AttendanceEvidence>.unmodifiable(
        attendanceEvidence,
      );

      final evaluations = await _evaluationRepository.listForStudent(
        student.id,
      );
      final evaluationEvidence = <EvaluationEvidence>[];
      for (final evaluation in evaluations) {
        final activity = await _activityRepository.findById(
          evaluation.activityId,
        );
        if (activity == null) continue;
        evaluationEvidence.add(
          EvaluationEvidence(
            activityTitle: activity.title,
            evaluation: evaluation,
          ),
        );
      }
      evaluationEvidence.sort(
        (left, right) => left.activityTitle.compareTo(right.activityTitle),
      );
      _evaluationEvidence = List<EvaluationEvidence>.unmodifiable(
        evaluationEvidence,
      );
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile({
    String? strengths,
    String? difficulties,
    String? supports,
  }) async {
    final student = _student;
    if (student == null || _isSaving) return false;
    return _mutate(() async {
      _record = await _updateStudentRecord(
        studentId: student.id,
        strengths: strengths,
        difficulties: difficulties,
        supports: supports,
      );
    });
  }

  Future<bool> addEntry({
    required StudentRecordEntryKind kind,
    required DateTime occurredAt,
    required String text,
  }) async {
    final student = _student;
    if (student == null || _isSaving) return false;
    return _mutate(() async {
      await _addStudentRecordEntry(
        studentId: student.id,
        kind: kind,
        occurredAt: occurredAt,
        text: text,
      );
      _entries = await _studentRecordRepository.listEntries(student.id);
    });
  }

  Future<bool> _mutate(Future<void> Function() mutation) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await mutation();
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
