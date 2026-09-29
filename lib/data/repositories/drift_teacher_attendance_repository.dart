import 'package:aularaiz/application/contracts/teacher_attendance_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_record.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_schedule.dart';
import 'package:drift/drift.dart';

final class DriftTeacherAttendanceRepository
    implements TeacherAttendanceRepository {
  DriftTeacherAttendanceRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<List<TeacherAttendanceRecord>> listForSchool(String schoolId) async {
    final rows =
        await (database.select(database.teacherAttendanceRecords)
              ..where(
                (table) =>
                    table.schoolId.equals(schoolId) & table.deletedAt.isNull(),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.attendanceDate)]))
            .get();
    return List<TeacherAttendanceRecord>.unmodifiable(rows.map(_toDomain));
  }

  @override
  Future<TeacherAttendanceRecord?> findForDate(
    String schoolId,
    DateTime date,
  ) async {
    final row =
        await (database.select(database.teacherAttendanceRecords)
              ..where(
                (table) =>
                    table.schoolId.equals(schoolId) &
                    table.attendanceDate.equals(_dateKey(date)) &
                    table.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> save(TeacherAttendanceRecord record) async {
    final now = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    final existing =
        await (database.select(database.teacherAttendanceRecords)
              ..where((table) => table.id.equals(record.id))
              ..limit(1))
            .getSingleOrNull();
    final values = TeacherAttendanceRecordsCompanion(
      id: Value(record.id),
      schoolId: Value(record.schoolId),
      attendanceDate: Value(_dateKey(record.attendanceDate)),
      arrivedAt: Value(record.arrivedAt.toUtc()),
      departedAt: Value(record.departedAt?.toUtc()),
      notes: Value(record.notes),
      correctedAt: Value(record.correctedAt?.toUtc()),
      expectedArrivalMinute: Value(record.expectedArrivalMinute),
      expectedDepartureMinute: Value(record.expectedDepartureMinute),
      arrivalGraceMinutes: Value(record.arrivalGraceMinutes),
      updatedAt: Value(now),
      deletedAt: const Value(null),
      updatedByDeviceId: deviceId,
    );
    if (existing == null) {
      await database
          .into(database.teacherAttendanceRecords)
          .insert(values.copyWith(createdAt: Value(now)));
      return;
    }
    await (database.update(
      database.teacherAttendanceRecords,
    )..where((table) => table.id.equals(record.id))).write(values);
  }

  @override
  Future<TeacherAttendanceSchedule> loadSchedule(String schoolId) async {
    final row =
        await (database.select(database.teacherAttendanceSchedules)
              ..where((table) => table.schoolId.equals(schoolId))
              ..limit(1))
            .getSingleOrNull();
    return TeacherAttendanceSchedule(
      schoolId: schoolId,
      expectedArrivalMinute: row?.expectedArrivalMinute,
      expectedDepartureMinute: row?.expectedDepartureMinute,
      arrivalGraceMinutes: row?.arrivalGraceMinutes ?? 10,
    );
  }

  @override
  Future<void> saveSchedule(TeacherAttendanceSchedule schedule) async {
    final now = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    final existing =
        await (database.select(database.teacherAttendanceSchedules)
              ..where((table) => table.schoolId.equals(schedule.schoolId))
              ..limit(1))
            .getSingleOrNull();
    final values = TeacherAttendanceSchedulesCompanion(
      schoolId: Value(schedule.schoolId),
      expectedArrivalMinute: Value(schedule.expectedArrivalMinute),
      expectedDepartureMinute: Value(schedule.expectedDepartureMinute),
      arrivalGraceMinutes: Value(schedule.arrivalGraceMinutes),
      updatedAt: Value(now),
      deletedAt: const Value(null),
      updatedByDeviceId: deviceId,
    );
    if (existing == null) {
      await database
          .into(database.teacherAttendanceSchedules)
          .insert(values.copyWith(createdAt: Value(now)));
      return;
    }
    await (database.update(database.teacherAttendanceSchedules)
          ..where((table) => table.schoolId.equals(schedule.schoolId)))
        .write(values);
  }

  TeacherAttendanceRecord _toDomain(TeacherAttendanceRow row) =>
      TeacherAttendanceRecord(
        id: row.id,
        schoolId: row.schoolId,
        attendanceDate: DateTime.parse(row.attendanceDate),
        arrivedAt: row.arrivedAt.toLocal(),
        departedAt: row.departedAt?.toLocal(),
        notes: row.notes,
        correctedAt: row.correctedAt?.toLocal(),
        expectedArrivalMinute: row.expectedArrivalMinute,
        expectedDepartureMinute: row.expectedDepartureMinute,
        arrivalGraceMinutes: row.arrivalGraceMinutes,
      );

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
