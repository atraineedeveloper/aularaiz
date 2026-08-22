import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/attendance/attendance_entry.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';

final class BuildDailyAttendance {
  BuildDailyAttendance({
    required AttendanceRepository attendanceRepository,
    required EnrollmentRepository enrollmentRepository,
    required IdGenerator idGenerator,
  }) : _attendanceRepository = attendanceRepository,
       _enrollmentRepository = enrollmentRepository,
       _idGenerator = idGenerator;

  final AttendanceRepository _attendanceRepository;
  final EnrollmentRepository _enrollmentRepository;
  final IdGenerator _idGenerator;

  Future<DailyAttendance> call({
    required String groupId,
    required DateTime date,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final existing = await _attendanceRepository.findByGroupAndDate(
      groupId,
      normalized,
    );
    if (existing != null) return existing;

    final enrollments = await _enrollmentRepository.findByGroupId(groupId);
    final active = enrollments.where(
      (enrollment) => enrollment.isActiveOn(normalized),
    );

    return DailyAttendance(
      id: _idGenerator.newId(),
      groupId: groupId,
      date: normalized,
      entries: [
        for (final enrollment in active)
          AttendanceEntry(
            studentId: enrollment.studentId,
            status: AttendanceStatus.present,
          ),
      ],
    );
  }
}
