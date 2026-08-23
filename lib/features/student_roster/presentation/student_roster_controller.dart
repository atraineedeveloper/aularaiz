import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student/student_sex.dart';
import 'package:flutter/foundation.dart';

enum StudentRosterFailureKind { load, mutation }

final class StudentRosterEntry {
  const StudentRosterEntry({required this.student, required this.enrollment});

  final Student student;
  final Enrollment enrollment;

  bool get isActive => enrollment.endsOn == null;
}

final class StudentRosterController extends ChangeNotifier {
  StudentRosterController({
    required StudentRepository studentRepository,
    required EnrollmentRepository enrollmentRepository,
    required CreateStudentInGroup createStudentInGroup,
    required ReactivateStudentInGroup reactivateStudentInGroup,
  }) : _studentRepository = studentRepository,
       _enrollmentRepository = enrollmentRepository,
       _createStudentInGroup = createStudentInGroup,
       _reactivateStudentInGroup = reactivateStudentInGroup;

  final StudentRepository _studentRepository;
  final EnrollmentRepository _enrollmentRepository;
  final CreateStudentInGroup _createStudentInGroup;
  final ReactivateStudentInGroup _reactivateStudentInGroup;

  TeachingGroup? _group;
  List<StudentRosterEntry> _allEntries = const [];
  String _query = '';
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;
  StudentRosterFailureKind? _failureKind;

  TeachingGroup? get group => _group;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;
  StudentRosterFailureKind? get failureKind => _failureKind;

  List<StudentRosterEntry> get entries {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _allEntries;
    return _allEntries
        .where((entry) {
          return entry.student.displayName.toLowerCase().contains(query) ||
              entry.enrollment.listNumber.toString() == query;
        })
        .toList(growable: false);
  }

  void setQuery(String query) {
    if (_query == query) return;
    _query = query;
    notifyListeners();
  }

  Future<void> load(TeachingGroup group) async {
    _group = group;
    _isLoading = true;
    _error = null;
    _failureKind = null;
    notifyListeners();

    try {
      await _reloadEntries();
    } catch (error) {
      _error = error;
      _failureKind = StudentRosterFailureKind.load;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createStudent({
    required String givenNames,
    required String firstSurname,
    String? secondSurname,
    StudentSex? sex,
    DateTime? birthDate,
    required PrimaryGrade grade,
    required int listNumber,
  }) async {
    final group = _group;
    if (group == null || _isSaving) return false;

    return _runMutation(() async {
      final result = await _createStudentInGroup(
        groupId: group.id,
        givenNames: givenNames,
        firstSurname: firstSurname,
        secondSurname: secondSurname,
        sex: sex,
        birthDate: birthDate,
        grade: grade,
        listNumber: listNumber,
      );
      if (result is CreateStudentInGroupRejected) return false;
      await _reloadEntries();
      return true;
    });
  }

  Future<bool> updateStudent({
    required StudentRosterEntry entry,
    required String givenNames,
    required String firstSurname,
    String? secondSurname,
    StudentSex? sex,
    DateTime? birthDate,
  }) async {
    if (_isSaving) return false;

    return _runMutation(() async {
      await _studentRepository.save(
        Student(
          id: entry.student.id,
          givenNames: givenNames,
          firstSurname: firstSurname,
          secondSurname: _optional(secondSurname),
          sex: sex,
          birthDate: birthDate,
        ),
      );
      await _reloadEntries();
      return true;
    });
  }

  Future<bool> deactivate(StudentRosterEntry entry, DateTime endsOn) async {
    if (!entry.isActive || _isSaving) return false;

    return _runMutation(() async {
      final effectiveEnd = endsOn.isBefore(entry.enrollment.startsOn)
          ? entry.enrollment.startsOn
          : endsOn;
      await _enrollmentRepository.save(
        Enrollment(
          id: entry.enrollment.id,
          studentId: entry.enrollment.studentId,
          groupId: entry.enrollment.groupId,
          grade: entry.enrollment.grade,
          listNumber: entry.enrollment.listNumber,
          startsOn: entry.enrollment.startsOn,
          endsOn: effectiveEnd,
        ),
      );
      await _reloadEntries();
      return true;
    });
  }

  Future<bool> reactivate({
    required StudentRosterEntry entry,
    required PrimaryGrade grade,
    required int listNumber,
  }) async {
    final group = _group;
    final previousEnd = entry.enrollment.endsOn;
    if (group == null || previousEnd == null || _isSaving) return false;

    return _runMutation(() async {
      final result = await _reactivateStudentInGroup(
        studentId: entry.student.id,
        groupId: group.id,
        grade: grade,
        listNumber: listNumber,
        startsOn: previousEnd.add(const Duration(days: 1)),
      );
      if (result is! EnrollStudentSucceeded) return false;
      await _reloadEntries();
      return true;
    });
  }

  Future<bool> _runMutation(Future<bool> Function() mutation) async {
    _isSaving = true;
    _error = null;
    _failureKind = null;
    notifyListeners();

    try {
      return await mutation();
    } catch (error) {
      _error = error;
      _failureKind = StudentRosterFailureKind.mutation;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reloadEntries() async {
    final group = _group;
    if (group == null) return;

    final enrollments = await _enrollmentRepository.findByGroupId(group.id);
    final latestByStudent = <String, Enrollment>{};
    for (final enrollment in enrollments) {
      final previous = latestByStudent[enrollment.studentId];
      if (previous == null || enrollment.startsOn.isAfter(previous.startsOn)) {
        latestByStudent[enrollment.studentId] = enrollment;
      }
    }

    final entries = <StudentRosterEntry>[];
    for (final enrollment in latestByStudent.values) {
      final student = await _studentRepository.findById(enrollment.studentId);
      if (student != null) {
        entries.add(
          StudentRosterEntry(student: student, enrollment: enrollment),
        );
      }
    }
    entries.sort(
      (left, right) =>
          left.enrollment.listNumber.compareTo(right.enrollment.listNumber),
    );
    _allEntries = List.unmodifiable(entries);
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
