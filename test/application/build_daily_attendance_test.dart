import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/attendance/attendance_entry.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new attendance freezes only students active on that date', () async {
    final attendanceRepository = _MemoryAttendanceRepository();
    final enrollmentRepository = _MemoryEnrollmentRepository([
      _enrollment('active', startsOn: DateTime(2026, 8, 1)),
      _enrollment(
        'ended',
        startsOn: DateTime(2026, 8, 1),
        endsOn: DateTime(2026, 8, 10),
      ),
      _enrollment('future', startsOn: DateTime(2026, 9, 1)),
    ]);
    final useCase = BuildDailyAttendance(
      attendanceRepository: attendanceRepository,
      enrollmentRepository: enrollmentRepository,
      idGenerator: _FixedIdGenerator(),
    );

    final result = await useCase(
      groupId: 'group-1',
      date: DateTime(2026, 8, 22, 18, 30),
    );

    expect(result.date, DateTime(2026, 8, 22));
    expect(result.entries.keys, <String>{'active'});
    expect(result.statusFor('active'), AttendanceStatus.present);
  });

  test('saved historical attendance is returned without rebuilding roster', () async {
    final saved = DailyAttendance(
      id: 'saved-day',
      groupId: 'group-1',
      date: DateTime(2026, 8, 20),
      entries: [
        AttendanceEntry(
          studentId: 'historical-student',
          status: AttendanceStatus.absent,
        ),
      ],
    );
    final attendanceRepository = _MemoryAttendanceRepository(saved: saved);
    final useCase = BuildDailyAttendance(
      attendanceRepository: attendanceRepository,
      enrollmentRepository: _MemoryEnrollmentRepository(const []),
      idGenerator: _FixedIdGenerator(),
    );

    final result = await useCase(
      groupId: 'group-1',
      date: DateTime(2026, 8, 20),
    );

    expect(result.id, 'saved-day');
    expect(result.entries.keys, <String>{'historical-student'});
    expect(
      result.statusFor('historical-student'),
      AttendanceStatus.absent,
    );
  });
}

Enrollment _enrollment(
  String studentId, {
  required DateTime startsOn,
  DateTime? endsOn,
}) {
  return Enrollment(
    id: 'enrollment-$studentId',
    studentId: studentId,
    groupId: 'group-1',
    grade: PrimaryGrade.first,
    listNumber: studentId.hashCode.abs() + 1,
    startsOn: startsOn,
    endsOn: endsOn,
  );
}

final class _FixedIdGenerator implements IdGenerator {
  @override
  String newId() => 'new-day';
}

final class _MemoryEnrollmentRepository implements EnrollmentRepository {
  _MemoryEnrollmentRepository(this.values);

  final List<Enrollment> values;

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async => values;

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async {
    return values
        .where((enrollment) => enrollment.studentId == studentId)
        .toList();
  }

  @override
  Future<void> save(Enrollment enrollment) async {}
}

final class _MemoryAttendanceRepository implements AttendanceRepository {
  _MemoryAttendanceRepository({this.saved});

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
