import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/attendance/attendance_entry.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:drift/drift.dart';

final class DriftAttendanceRepository implements AttendanceRepository {
  DriftAttendanceRepository(this.database);

  final AppDatabase database;

  @override
  Future<DailyAttendance?> findByGroupAndDate(
    String groupId,
    DateTime date,
  ) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final day =
        await (database.select(database.attendanceDays)
              ..where(
                (table) =>
                    table.groupId.equals(groupId) &
                    table.date.equals(normalized),
              )
              ..limit(1))
            .getSingleOrNull();
    if (day == null) return null;

    return _loadDay(day.id, day.groupId, day.date);
  }

  @override
  Future<List<DailyAttendance>> listForMonth(
    String groupId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final days =
        await (database.select(database.attendanceDays)
              ..where(
                (table) =>
                    table.groupId.equals(groupId) &
                    table.date.isBiggerOrEqualValue(start) &
                    table.date.isSmallerThanValue(end),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.date)]))
            .get();

    final result = <DailyAttendance>[];
    for (final day in days) {
      result.add(await _loadDay(day.id, day.groupId, day.date));
    }
    return List<DailyAttendance>.unmodifiable(result);
  }

  @override
  Future<void> save(DailyAttendance attendance) async {
    await database.transaction(() async {
      await database
          .into(database.attendanceDays)
          .insertOnConflictUpdate(
            AttendanceDaysCompanion(
              id: Value(attendance.id),
              groupId: Value(attendance.groupId),
              date: Value(attendance.date),
            ),
          );

      await (database.delete(
        database.attendanceEntries,
      )..where((table) => table.attendanceDayId.equals(attendance.id))).go();

      await database.batch((batch) {
        for (final entry in attendance.entries.values) {
          batch.insert(
            database.attendanceEntries,
            AttendanceEntriesCompanion(
              attendanceDayId: Value(attendance.id),
              studentId: Value(entry.studentId),
              status: Value(entry.status),
            ),
          );
        }
      });
    });
  }

  Future<DailyAttendance> _loadDay(
    String id,
    String groupId,
    DateTime date,
  ) async {
    final rows = await (database.select(
      database.attendanceEntries,
    )..where((table) => table.attendanceDayId.equals(id))).get();
    return DailyAttendance(
      id: id,
      groupId: groupId,
      date: date,
      entries: [
        for (final row in rows)
          AttendanceEntry(studentId: row.studentId, status: row.status),
      ],
    );
  }
}
