import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/literacy_assessment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/literacy/save_literacy_assessment.dart';
import 'package:aularaiz/application/literacy/update_literacy_assessment.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:flutter/foundation.dart';

final class LiteracyRosterEntry {
  const LiteracyRosterEntry({
    required this.student,
    required this.enrollment,
    required this.latestAssessment,
    required this.isActive,
  });

  final Student student;
  final Enrollment enrollment;
  final LiteracyAssessment? latestAssessment;
  final bool isActive;

  bool get hasAssessment => latestAssessment != null;

  bool get needsPrioritySupport {
    final assessment = latestAssessment;
    if (assessment == null) return false;
    return _readingNeedsPrioritySupport(assessment.readingLevel) ||
        _writingNeedsPrioritySupport(assessment.writingLevel);
  }

  static bool _readingNeedsPrioritySupport(ReadingLevel level) {
    return switch (level) {
      ReadingLevel.doesNotRead ||
      ReadingLevel.syllabic ||
      ReadingLevel.wordByWord => true,
      ReadingLevel.sentence || ReadingLevel.fluent => false,
    };
  }

  static bool _writingNeedsPrioritySupport(WritingLevel level) {
    return switch (level) {
      WritingLevel.presyllabic ||
      WritingLevel.syllabic ||
      WritingLevel.syllabicAlphabetic => true,
      WritingLevel.alphabetic => false,
    };
  }
}

enum LiteracyFilter { all, pending, prioritySupport, historical }

final class LiteracyController extends ChangeNotifier {
  LiteracyController({
    required EnrollmentRepository enrollmentRepository,
    required StudentRepository studentRepository,
    required LiteracyAssessmentRepository literacyAssessmentRepository,
    required SaveLiteracyAssessment saveLiteracyAssessment,
    required UpdateLiteracyAssessment updateLiteracyAssessment,
  }) : _enrollmentRepository = enrollmentRepository,
       _studentRepository = studentRepository,
       _literacyAssessmentRepository = literacyAssessmentRepository,
       _saveLiteracyAssessment = saveLiteracyAssessment,
       _updateLiteracyAssessment = updateLiteracyAssessment;

  final EnrollmentRepository _enrollmentRepository;
  final StudentRepository _studentRepository;
  final LiteracyAssessmentRepository _literacyAssessmentRepository;
  final SaveLiteracyAssessment _saveLiteracyAssessment;
  final UpdateLiteracyAssessment _updateLiteracyAssessment;

  TeachingGroup? _group;
  List<LiteracyRosterEntry> _entries = const [];
  LiteracyFilter _filter = LiteracyFilter.all;
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  TeachingGroup? get group => _group;
  List<LiteracyRosterEntry> get entries => _entries;
  LiteracyFilter get filter => _filter;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;

  List<LiteracyRosterEntry> get filteredEntries {
    return switch (_filter) {
      LiteracyFilter.all => _activeEntries,
      LiteracyFilter.pending =>
        _activeEntries
            .where((entry) => entry.latestAssessment == null)
            .toList(growable: false),
      LiteracyFilter.prioritySupport =>
        _activeEntries
            .where((entry) => entry.needsPrioritySupport)
            .toList(growable: false),
      LiteracyFilter.historical =>
        _entries.where((entry) => !entry.isActive).toList(growable: false),
    };
  }

  List<LiteracyRosterEntry> get _activeEntries =>
      _entries.where((entry) => entry.isActive).toList(growable: false);

  int get activeStudentCount => _activeEntries.length;

  int get historicalStudentCount =>
      _entries.where((entry) => !entry.isActive).length;

  int get assessedCount =>
      _activeEntries.where((entry) => entry.latestAssessment != null).length;

  int get pendingCount => activeStudentCount - assessedCount;

  int get prioritySupportCount =>
      _activeEntries.where((entry) => entry.needsPrioritySupport).length;

  Future<void> load(TeachingGroup group, {DateTime? referenceDate}) async {
    _group = group;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final when = referenceDate ?? DateTime.now();
      final enrollments = await _enrollmentRepository.findByGroupId(group.id);
      final latestEnrollmentByStudent = <String, Enrollment>{};
      for (final enrollment in enrollments) {
        final current = latestEnrollmentByStudent[enrollment.studentId];
        if (current == null || enrollment.startsOn.isAfter(current.startsOn)) {
          latestEnrollmentByStudent[enrollment.studentId] = enrollment;
        }
      }

      final loaded = <LiteracyRosterEntry>[];
      for (final enrollment in latestEnrollmentByStudent.values) {
        final student = await _studentRepository.findById(enrollment.studentId);
        if (student == null) continue;
        final latestAssessment = await _literacyAssessmentRepository
            .latestForStudent(student.id);
        loaded.add(
          LiteracyRosterEntry(
            student: student,
            enrollment: enrollment,
            latestAssessment: latestAssessment,
            isActive: enrollment.isActiveOn(when),
          ),
        );
      }

      loaded.sort((left, right) {
        if (left.isActive != right.isActive) return left.isActive ? -1 : 1;
        final byGrade = left.enrollment.grade.number.compareTo(
          right.enrollment.grade.number,
        );
        if (byGrade != 0) return byGrade;
        final byList = left.enrollment.listNumber.compareTo(
          right.enrollment.listNumber,
        );
        if (byList != 0) return byList;
        return left.student.displayName.compareTo(right.student.displayName);
      });

      _entries = List<LiteracyRosterEntry>.unmodifiable(loaded);
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('load_literacy_dashboard', error);
      _entries = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(LiteracyFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  Future<bool> saveAssessment({
    required LiteracyRosterEntry entry,
    required DateTime assessedAt,
    required WritingLevel writingLevel,
    required ReadingLevel readingLevel,
    required String notes,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final current = entry.latestAssessment;
      if (current == null) {
        await _saveLiteracyAssessment(
          studentId: entry.student.id,
          assessedAt: assessedAt,
          writingLevel: writingLevel,
          readingLevel: readingLevel,
          notes: notes,
        );
      } else {
        await _updateLiteracyAssessment(
          id: current.id,
          assessedAt: assessedAt,
          writingLevel: writingLevel,
          readingLevel: readingLevel,
          notes: notes,
        );
      }
      final group = _group;
      if (group != null) await load(group);
      return true;
    } catch (error) {
      SafeLog.operationFailure('save_literacy_dashboard_assessment', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterSync() async {
    final group = _group;
    if (group == null || _isLoading) return;
    await load(group);
  }
}
