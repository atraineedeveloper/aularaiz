import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:flutter/foundation.dart';

export 'package:aularaiz/features/student_record/presentation/student_record_localization.dart';

final class StudentRecordRosterEntry {
  const StudentRecordRosterEntry({
    required this.student,
    required this.enrollment,
    required this.isActive,
  });

  final Student student;
  final Enrollment enrollment;
  final bool isActive;
}

final class StudentRecordsController extends ChangeNotifier {
  StudentRecordsController({
    required EnrollmentRepository enrollmentRepository,
    required StudentRepository studentRepository,
  }) : _enrollmentRepository = enrollmentRepository,
       _studentRepository = studentRepository;

  final EnrollmentRepository _enrollmentRepository;
  final StudentRepository _studentRepository;

  TeachingGroup? _group;
  List<StudentRecordRosterEntry> _entries = const [];
  bool _isLoading = false;
  Object? _error;

  TeachingGroup? get group => _group;
  List<StudentRecordRosterEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> load(TeachingGroup group, {DateTime? referenceDate}) async {
    _group = group;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final when = referenceDate ?? DateTime.now();
      final enrollments = await _enrollmentRepository.findByGroupId(group.id);
      final latestByStudent = <String, Enrollment>{};
      for (final enrollment in enrollments) {
        final current = latestByStudent[enrollment.studentId];
        if (current == null || enrollment.startsOn.isAfter(current.startsOn)) {
          latestByStudent[enrollment.studentId] = enrollment;
        }
      }

      final result = <StudentRecordRosterEntry>[];
      for (final enrollment in latestByStudent.values) {
        final student = await _studentRepository.findById(enrollment.studentId);
        if (student == null) continue;
        result.add(
          StudentRecordRosterEntry(
            student: student,
            enrollment: enrollment,
            isActive: enrollment.isActiveOn(when),
          ),
        );
      }
      result.sort((left, right) {
        if (left.isActive != right.isActive) return left.isActive ? -1 : 1;
        final byList = left.enrollment.listNumber.compareTo(
          right.enrollment.listNumber,
        );
        if (byList != 0) return byList;
        return left.student.displayName.compareTo(right.student.displayName);
      });
      _entries = List<StudentRecordRosterEntry>.unmodifiable(result);
    } catch (error) {
      _error = error;
      _entries = const [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
