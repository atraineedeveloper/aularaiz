import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';

final class AttendanceStatusChange {
  const AttendanceStatusChange({
    required this.attendance,
    required this.previousStatus,
    required this.status,
  });

  final DailyAttendance attendance;
  final AttendanceStatus previousStatus;
  final AttendanceStatus status;
}

final class SetStudentAttendanceStatus {
  const SetStudentAttendanceStatus({
    required BuildDailyAttendance buildDailyAttendance,
    required AttendanceRepository attendanceRepository,
  }) : _buildDailyAttendance = buildDailyAttendance,
       _attendanceRepository = attendanceRepository;

  final BuildDailyAttendance _buildDailyAttendance;
  final AttendanceRepository _attendanceRepository;

  Future<AttendanceStatusChange> preview({
    required String groupId,
    required String studentId,
    required DateTime date,
    required AttendanceStatus status,
  }) async {
    final normalizedGroupId = groupId.trim();
    final normalizedStudentId = studentId.trim();
    if (normalizedGroupId.isEmpty) {
      throw ArgumentError.value(groupId, 'groupId', 'Group id cannot be empty.');
    }
    if (normalizedStudentId.isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Student id cannot be empty.',
      );
    }

    final attendance = await _buildDailyAttendance(
      groupId: normalizedGroupId,
      date: date,
    );
    final previousStatus = attendance.statusFor(normalizedStudentId);
    if (previousStatus == null) {
      throw StateError(
        'Student is not part of the historical attendance roster for this date.',
      );
    }

    return AttendanceStatusChange(
      attendance: previousStatus == status
          ? attendance
          : attendance.withStatus(normalizedStudentId, status),
      previousStatus: previousStatus,
      status: status,
    );
  }

  Future<AttendanceStatusChange> call({
    required String groupId,
    required String studentId,
    required DateTime date,
    required AttendanceStatus status,
  }) async {
    final change = await preview(
      groupId: groupId,
      studentId: studentId,
      date: date,
      status: status,
    );
    await _attendanceRepository.save(change.attendance);
    return change;
  }
}
