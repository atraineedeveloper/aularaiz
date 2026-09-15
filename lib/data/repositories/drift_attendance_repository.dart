import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/attendance/attendance_entry.dart' as domain;
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:drift/drift.dart';

final class DriftAttendanceRepository
    implements AttendanceRepository, DeletableAttendanceRepository {
  DriftAttendanceRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<void> deleteByGroupAndDate(String groupId, DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      final days =
          await (database.select(database.attendanceDays)..where(
                (t) =>
                    t.groupId.equals(groupId) &
                    t.date.equals(normalized) &
                    t.deletedAt.isNull(),
              ))
              .get();
      for (final day in days) {
        await (database.update(
          database.attendanceEntries,
        )..where((t) => t.attendanceDayId.equals(day.id))).write(
          AttendanceEntriesCompanion(
            deletedAt: SyncMetadataValues.deleted(timestamp),
            updatedAt: SyncMetadataValues.updated(timestamp),
            updatedByDeviceId: deviceId,
          ),
        );
        await (database.update(
          database.attendanceDays,
        )..where((t) => t.id.equals(day.id))).write(
          AttendanceDaysCompanion(
            deletedAt: SyncMetadataValues.deleted(timestamp),
            updatedAt: SyncMetadataValues.updated(timestamp),
            updatedByDeviceId: deviceId,
          ),
        );
      }
    });
  }

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
                    table.date.equals(normalized) &
                    table.deletedAt.isNull(),
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
                    table.date.isSmallerThanValue(end) &
                    table.deletedAt.isNull(),
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
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      await database
          .into(database.attendanceDays)
          .insertOnConflictUpdate(
            AttendanceDaysCompanion(
              id: Value(attendance.id),
              groupId: Value(attendance.groupId),
              date: Value(attendance.date),
              deletedAt: const Value(null),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );

      await (database.update(
        database.attendanceEntries,
      )..where((table) => table.attendanceDayId.equals(attendance.id))).write(
        AttendanceEntriesCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );

      await database.batch((batch) {
        for (final entry in attendance.entries.values) {
          batch.insert(
            database.attendanceEntries,
            AttendanceEntriesCompanion(
              attendanceDayId: Value(attendance.id),
              studentId: Value(entry.studentId),
              status: Value(entry.status),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              deletedAt: const Value(null),
              updatedByDeviceId: deviceId,
            ),
            mode: InsertMode.insertOrReplace,
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
    final rows =
        await (database.select(database.attendanceEntries)..where(
              (table) =>
                  table.attendanceDayId.equals(id) & table.deletedAt.isNull(),
            ))
            .get();
    return DailyAttendance(
      id: id,
      groupId: groupId,
      date: date,
      entries: [
        for (final row in rows)
          domain.AttendanceEntry(studentId: row.studentId, status: row.status),
      ],
    );
  }
}
