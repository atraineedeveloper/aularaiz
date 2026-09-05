import 'package:aularaiz/domain/attendance/daily_attendance.dart';

abstract interface class AttendanceRepository {
  Future<DailyAttendance?> findByGroupAndDate(String groupId, DateTime date);

  Future<List<DailyAttendance>> listForMonth(String groupId, DateTime month);

  Future<void> save(DailyAttendance attendance);
}

abstract interface class DeletableAttendanceRepository {
  Future<void> deleteByGroupAndDate(String groupId, DateTime date);
}
