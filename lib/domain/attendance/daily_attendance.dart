import 'package:aularaiz/domain/attendance/attendance_entry.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';

final class DailyAttendance {
  DailyAttendance({
    required this.id,
    required this.groupId,
    required DateTime date,
    required Iterable<AttendanceEntry> entries,
  }) : date = DateTime(date.year, date.month, date.day),
       entries = _buildEntries(entries) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Attendance id cannot be empty.');
    }
    if (groupId.trim().isEmpty) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Attendance group id cannot be empty.',
      );
    }
  }

  final String id;
  final String groupId;
  final DateTime date;
  final Map<String, AttendanceEntry> entries;

  AttendanceStatus? statusFor(String studentId) => entries[studentId]?.status;

  int count(AttendanceStatus status) {
    return entries.values.where((entry) => entry.status == status).length;
  }

  DailyAttendance withStatus(String studentId, AttendanceStatus status) {
    final current = entries[studentId];
    if (current == null) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Student is not part of this historical attendance roster.',
      );
    }

    return DailyAttendance(
      id: id,
      groupId: groupId,
      date: date,
      entries: <AttendanceEntry>[
        for (final entry in entries.values)
          if (entry.studentId == studentId) entry.withStatus(status) else entry,
      ],
    );
  }

  static Map<String, AttendanceEntry> _buildEntries(
    Iterable<AttendanceEntry> source,
  ) {
    final result = <String, AttendanceEntry>{};
    for (final entry in source) {
      if (result.containsKey(entry.studentId)) {
        throw ArgumentError.value(
          entry.studentId,
          'entries',
          'Attendance roster cannot contain duplicate students.',
        );
      }
      result[entry.studentId] = entry;
    }
    return Map<String, AttendanceEntry>.unmodifiable(result);
  }
}
