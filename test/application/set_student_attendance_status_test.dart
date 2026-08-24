import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/attendance/set_student_attendance_status.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview validates attendance change without persisting', () async {
    final attendanceRepository = _MemoryAttendanceRepository();
    final useCase = SetStudentAttendanceStatus(
      buildDailyAttendance: BuildDailyAttendance(
        attendanceRepository: attendanceRepository,
        enrollmentRepository: _MemoryEnrollmentRepository([
          _enrollment('student-1'),
        ]),
        idGenerator: _FixedIdGenerator(),
      ),
      attendanceRepository: attendanceRepository,
    );

    final change = await useCase.preview(
      groupId: 'group-1',
      studentId: 'student-1',
      date: DateTime(2026, 9, 3),
      status: AttendanceStatus.absent,
    );

    expect(change.previousStatus, AttendanceStatus.present);
    expect(change.status, AttendanceStatus.absent);
    expect(change.attendance.statusFor('student-1'), AttendanceStatus.absent);
    expect(attendanceRepository.saved, isNull);
  });

  test('apply persists through attendance repository', () async {
    final attendanceRepository = _MemoryAttendanceRepository();
    final useCase = SetStudentAttendanceStatus(
      buildDailyAttendance: BuildDailyAttendance(
        attendanceRepository: attendanceRepository,
        enrollmentRepository: _MemoryEnrollmentRepository([
          _enrollment('student-1'),
        ]),
        idGenerator: _FixedIdGenerator(),
      ),
      attendanceRepository: attendanceRepository,
    );

    final change = await useCase(
      groupId: 'group-1',
      studentId: 'student-1',
      date: DateTime(2026, 9, 3),
      status: AttendanceStatus.late,
    );

    expect(change.attendance.statusFor('student-1'), AttendanceStatus.late);
    expect(
      attendanceRepository.saved?.statusFor('student-1'),
      AttendanceStatus.late,
    );
  });

  test('student outside historical roster is rejected', () async {
    final attendanceRepository = _MemoryAttendanceRepository();
    final useCase = SetStudentAttendanceStatus(
      buildDailyAttendance: BuildDailyAttendance(
        attendanceRepository: attendanceRepository,
        enrollmentRepository: _MemoryEnrollmentRepository([
          _enrollment('student-1'),
        ]),
        idGenerator: _FixedIdGenerator(),
      ),
      attendanceRepository: attendanceRepository,
    );

    expect(
      () => useCase.preview(
        groupId: 'group-1',
        studentId: 'student-2',
        date: DateTime(2026, 9, 3),
        status: AttendanceStatus.absent,
      ),
      throwsStateError,
    );
  });
}

Enrollment _enrollment(String studentId) => Enrollment(
  id: 'enrollment-$studentId',
  studentId: studentId,
  groupId: 'group-1',
  grade: PrimaryGrade.first,
  listNumber: 1,
  startsOn: DateTime(2026, 8, 1),
);

final class _FixedIdGenerator implements IdGenerator {
  @override
  String newId() => 'attendance-1';
}

final class _MemoryEnrollmentRepository implements EnrollmentRepository {
  _MemoryEnrollmentRepository(this.values);

  final List<Enrollment> values;

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async => values;

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async =>
      values.where((enrollment) => enrollment.studentId == studentId).toList();

  @override
  Future<void> save(Enrollment enrollment) async {}
}

final class _MemoryAttendanceRepository implements AttendanceRepository {
  DailyAttendance? saved;

  @override
  Future<DailyAttendance?> findByGroupAndDate(
    String groupId,
    DateTime date,
  ) async => saved;

  @override
  Future<List<DailyAttendance>> listForMonth(
    String groupId,
    DateTime month,
  ) async => saved == null ? const [] : [saved!];

  @override
  Future<void> save(DailyAttendance attendance) async {
    saved = attendance;
  }
}
