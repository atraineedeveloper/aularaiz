import 'package:aularaiz/application/attendance/set_student_attendance_status.dart';
import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/application/student/deactivate_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';

typedef AutomationMutationClock = DateTime Function();

final class AutomationMutationService {
  AutomationMutationService({
    required TeachingGroupRepository teachingGroupRepository,
    required StudentRepository studentRepository,
    required EnrollmentRepository enrollmentRepository,
    required SetStudentAttendanceStatus setStudentAttendanceStatus,
    required DeactivateStudentInGroup deactivateStudentInGroup,
    required ReactivateStudentInGroup reactivateStudentInGroup,
    AutomationMutationClock? clock,
  }) : _teachingGroupRepository = teachingGroupRepository,
       _studentRepository = studentRepository,
       _enrollmentRepository = enrollmentRepository,
       _setStudentAttendanceStatus = setStudentAttendanceStatus,
       _deactivateStudentInGroup = deactivateStudentInGroup,
       _reactivateStudentInGroup = reactivateStudentInGroup,
       _clock = clock ?? DateTime.now;

  final TeachingGroupRepository _teachingGroupRepository;
  final StudentRepository _studentRepository;
  final EnrollmentRepository _enrollmentRepository;
  final SetStudentAttendanceStatus _setStudentAttendanceStatus;
  final DeactivateStudentInGroup _deactivateStudentInGroup;
  final ReactivateStudentInGroup _reactivateStudentInGroup;
  final AutomationMutationClock _clock;

  Future<AutomationEnvelope> setAttendance({
    required String groupId,
    required String studentId,
    required DateTime date,
    required AttendanceStatus status,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final student = await _requireStudent(studentId);
    final change = apply
        ? await _setStudentAttendanceStatus(
            groupId: group.id,
            studentId: student.id,
            date: date,
            status: status,
          )
        : await _setStudentAttendanceStatus.preview(
            groupId: group.id,
            studentId: student.id,
            date: date,
            status: status,
          );

    return _envelope(
      kind: 'attendance-set',
      privacy: privacy,
      data: <String, Object?>{
        'operation': 'set-attendance-status',
        'dry_run': !apply,
        'applied': apply,
        'group': _groupProjection(group),
        'date': _dateLabel(change.attendance.date),
        'previous_status': _attendanceStatusLabel(change.previousStatus),
        'status': _attendanceStatusLabel(change.status),
        if (privacy.includePersonalData)
          'student': _personalStudentIdentity(student),
      },
    );
  }

  Future<AutomationEnvelope> deactivateStudent({
    required String groupId,
    required String studentId,
    required DateTime endsOn,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final student = await _requireStudent(studentId);
    final plan = apply
        ? await _deactivateStudentInGroup(
            studentId: student.id,
            groupId: group.id,
            endsOn: endsOn,
          )
        : await _deactivateStudentInGroup.preview(
            studentId: student.id,
            groupId: group.id,
            endsOn: endsOn,
          );

    return _envelope(
      kind: 'student-deactivate',
      privacy: privacy,
      data: <String, Object?>{
        'operation': 'deactivate-student-in-group',
        'dry_run': !apply,
        'applied': apply,
        'group': _groupProjection(group),
        'ends_on': _dateLabel(plan.endsOn),
        'grade': plan.currentEnrollment.grade.number,
        if (privacy.includePersonalData) ...<String, Object?>{
          'student': _personalStudentIdentity(student),
          'list_number': plan.currentEnrollment.listNumber,
        },
      },
    );
  }

  Future<AutomationEnvelope> reactivateStudent({
    required String groupId,
    required String studentId,
    required PrimaryGrade grade,
    required int listNumber,
    DateTime? startsOn,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final student = await _requireStudent(studentId);
    final previous = await _latestEnrollment(
      groupId: group.id,
      studentId: student.id,
    );
    final previousEnd = previous.endsOn;
    if (previousEnd == null) {
      throw StateError('Student already has an active enrollment in this group.');
    }

    final effectiveStart = startsOn == null
        ? _date(previousEnd.add(const Duration(days: 1)))
        : _date(startsOn);
    final result = apply
        ? await _reactivateStudentInGroup(
            studentId: student.id,
            groupId: group.id,
            grade: grade,
            listNumber: listNumber,
            startsOn: effectiveStart,
          )
        : await _reactivateStudentInGroup.preview(
            studentId: student.id,
            groupId: group.id,
            grade: grade,
            listNumber: listNumber,
            startsOn: effectiveStart,
          );
    _requireEnrollmentSuccess(result);

    return _envelope(
      kind: 'student-reactivate',
      privacy: privacy,
      data: <String, Object?>{
        'operation': 'reactivate-student-in-group',
        'dry_run': !apply,
        'applied': apply,
        'group': _groupProjection(group),
        'starts_on': _dateLabel(effectiveStart),
        'grade': grade.number,
        if (privacy.includePersonalData) ...<String, Object?>{
          'student': _personalStudentIdentity(student),
          'list_number': listNumber,
        },
      },
    );
  }

  Future<TeachingGroup> _requireGroup(String groupId) async {
    final normalized = groupId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id cannot be empty.');
    }
    final group = await _teachingGroupRepository.findById(normalized);
    if (group == null) throw StateError('Teaching group does not exist.');
    return group;
  }

  Future<Student> _requireStudent(String studentId) async {
    final normalized = studentId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Student id cannot be empty.',
      );
    }
    final student = await _studentRepository.findById(normalized);
    if (student == null) throw StateError('Student does not exist.');
    return student;
  }

  Future<Enrollment> _latestEnrollment({
    required String groupId,
    required String studentId,
  }) async {
    final matches = (await _enrollmentRepository.findByGroupId(groupId))
        .where((enrollment) => enrollment.studentId == studentId)
        .toList(growable: false)
      ..sort((left, right) => right.startsOn.compareTo(left.startsOn));
    if (matches.isEmpty) {
      throw StateError('Student has no enrollment history in this group.');
    }
    return matches.first;
  }

  void _requireEnrollmentSuccess(EnrollStudentResult result) {
    switch (result) {
      case EnrollStudentSucceeded():
        return;
      case EnrollStudentMissingReference(:final reference):
        throw StateError('Missing enrollment reference: ${reference.name}.');
      case EnrollStudentRejected(:final violations):
        final codes = violations.map((violation) => violation.name).join(', ');
        throw StateError('Enrollment policy rejected reactivation: $codes.');
    }
  }

  AutomationEnvelope _envelope({
    required String kind,
    required AutomationPrivacy privacy,
    required Map<String, Object?> data,
  }) {
    return AutomationEnvelope(
      kind: kind,
      privacy: privacy,
      data: data,
      generatedAt: _clock(),
    );
  }
}

Map<String, Object?> _groupProjection(TeachingGroup group) => <String, Object?>{
  'id': group.id,
  'name': group.name,
  'grades': group.grades.map((grade) => grade.number).toList(growable: false)
    ..sort(),
  'multigrade': group.isMultigrade,
  if (group.shift != null) 'shift': group.shift,
};

Map<String, Object?> _personalStudentIdentity(Student student) =>
    <String, Object?>{'student_id': student.id, 'name': student.displayName};

String _attendanceStatusLabel(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => 'present',
  AttendanceStatus.absent => 'absent',
  AttendanceStatus.late => 'late',
  AttendanceStatus.justifiedAbsence => 'justified-absence',
};

DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);

String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
