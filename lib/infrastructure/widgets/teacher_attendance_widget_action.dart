import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_teacher_attendance_repository.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_record.dart';
import 'package:drift/drift.dart';

enum TeacherWidgetActionResult { saved, unchanged, stale, unavailable }

/// Serializes a widget tap against the actual database, including taps from
/// separate background engines. An arrival request never becomes a departure.
final class TeacherAttendanceWidgetAction {
  TeacherAttendanceWidgetAction(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : repository = DriftTeacherAttendanceRepository(
         database,
         deviceIdProvider: deviceIdProvider,
       );

  final AppDatabase database;
  final DriftTeacherAttendanceRepository repository;

  Future<TeacherWidgetActionResult> apply({
    required String schoolId,
    required String action,
    required String expectedDate,
    DateTime? at,
  }) async {
    final now = at ?? DateTime.now();
    final dateKey =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    if (expectedDate != dateKey) return TeacherWidgetActionResult.stale;
    if (!const {'arrival', 'departure'}.contains(action)) {
      return TeacherWidgetActionResult.unavailable;
    }

    return database.transaction(() async {
      // Acquire SQLite's write lock before reading. This prevents a queued
      // duplicate tap from reading a state another connection is changing.
      await database.customStatement(
        'UPDATE teacher_attendance_records SET id = id WHERE 0',
      );
      final school =
          await (database.select(database.schools)..where(
                (table) => table.id.equals(schoolId) & table.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (school == null) return TeacherWidgetActionResult.unavailable;

      final record = await repository.findForDate(schoolId, now);
      if (action == 'arrival') {
        if (record != null) return TeacherWidgetActionResult.unchanged;
        final schedule = await repository.loadSchedule(schoolId);
        await repository.save(
          TeacherAttendanceRecord(
            id: 'teacher-attendance:$schoolId:$dateKey',
            schoolId: schoolId,
            attendanceDate: now,
            arrivedAt: now,
            expectedArrivalMinute: schedule.expectedArrivalMinute,
            expectedDepartureMinute: schedule.expectedDepartureMinute,
            arrivalGraceMinutes: schedule.isConfigured
                ? schedule.arrivalGraceMinutes
                : null,
          ),
        );
      } else {
        if (record == null ||
            !record.isOpen ||
            now.isBefore(record.arrivedAt)) {
          return TeacherWidgetActionResult.unchanged;
        }
        await repository.save(record.copyWith(departedAt: now));
      }
      return TeacherWidgetActionResult.saved;
    });
  }
}
