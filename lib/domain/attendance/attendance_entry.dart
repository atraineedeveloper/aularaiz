import 'package:aularaiz/domain/attendance/attendance_status.dart';

final class AttendanceEntry {
  AttendanceEntry({required this.studentId, required this.status}) {
    if (studentId.trim().isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Attendance student id cannot be empty.',
      );
    }
  }

  final String studentId;
  final AttendanceStatus status;

  AttendanceEntry withStatus(AttendanceStatus nextStatus) {
    return AttendanceEntry(studentId: studentId, status: nextStatus);
  }
}
