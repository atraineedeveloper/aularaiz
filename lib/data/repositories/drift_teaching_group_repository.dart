import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:drift/drift.dart';

final class DriftTeachingGroupRepository
    implements TeachingGroupRepository, DeletableTeachingGroupRepository {
  DriftTeachingGroupRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<TeachingGroup?> findById(String id) async {
    final row =
        await (database.select(
              database.teachingGroups,
            )..where((table) => table.id.equals(id) & table.deletedAt.isNull()))
            .getSingleOrNull();

    if (row == null) return null;
    return _toDomain(row);
  }

  @override
  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId) async {
    final rows =
        await (database.select(database.teachingGroups)..where(
              (table) =>
                  table.schoolYearId.equals(schoolYearId) &
                  table.deletedAt.isNull(),
            ))
            .get();
    final groups = <TeachingGroup>[];

    for (final row in rows) {
      groups.add(await _toDomain(row));
    }

    groups.sort((left, right) => left.name.compareTo(right.name));
    return groups;
  }

  @override
  Future<void> save(TeachingGroup group) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      await database
          .into(database.teachingGroups)
          .insertOnConflictUpdate(
            TeachingGroupsCompanion(
              id: Value(group.id),
              schoolId: Value(group.schoolId),
              schoolYearId: Value(group.schoolYearId),
              name: Value(group.name),
              shift: Value(group.shift),
              scheduleStartMinutes: Value(group.schedule?.startsAtMinutes),
              scheduleEndMinutes: Value(group.schedule?.endsAtMinutes),
              contractStartsOn: Value(group.contract?.startsOn),
              contractEndsOn: Value(group.contract?.endsOn),
              teachingRole: Value(group.teachingRole),
              deletedAt: const Value(null),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );

      final existingRows =
          await (database.select(database.groupGrades)..where(
                (table) =>
                    table.groupId.equals(group.id) & table.deletedAt.isNull(),
              ))
              .get();
      final existingGrades = existingRows.map((row) => row.grade).toSet();
      final removedGrades = existingGrades.difference(group.grades);
      final addedGrades = group.grades.difference(existingGrades);

      for (final grade in removedGrades) {
        await (database.update(database.groupGrades)..where(
              (table) =>
                  table.groupId.equals(group.id) &
                  table.grade.equalsValue(grade),
            ))
            .write(
              GroupGradesCompanion(
                deletedAt: SyncMetadataValues.deleted(timestamp),
                updatedAt: SyncMetadataValues.updated(timestamp),
                updatedByDeviceId: deviceId,
              ),
            );
      }

      await database.batch((batch) {
        for (final grade in addedGrades) {
          batch.insert(
            database.groupGrades,
            GroupGradesCompanion(
              groupId: Value(group.id),
              grade: Value(grade),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
              deletedAt: const Value(null),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await database.transaction(() async {
      final timestamp = SyncMetadataValues.now();
      final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
      final deviceIdValue = deviceId.value;
      final exists =
          await (database.select(database.teachingGroups)
                ..where(
                  (table) =>
                      table.id.equals(groupId) & table.deletedAt.isNull(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (exists == null) throw StateError('Teaching group does not exist.');
      await _deleteGroupData(groupId, timestamp, deviceIdValue);
      await _deleteOrphanStudents(timestamp, deviceIdValue);
    });
  }

  Future<void> _deleteGroupData(
    String groupId,
    DateTime timestamp,
    String? deviceId,
  ) async {
    final deletedAt = timestamp.millisecondsSinceEpoch;
    const activityIds = '''
      SELECT a.id
      FROM activities a
      INNER JOIN projects p ON p.id = a.project_id
      WHERE p.group_id = ? AND a.deleted_at IS NULL AND p.deleted_at IS NULL
    ''';
    const projectIds =
        'SELECT id FROM projects WHERE group_id = ? AND deleted_at IS NULL';

    for (final table in <String>[
      'activity_evaluations',
      'activity_roster',
      'activity_grades',
      'activity_formative_fields',
    ]) {
      await database.customStatement(
        'UPDATE $table SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? '
        'WHERE activity_id IN ($activityIds)',
        <Object?>[deletedAt, deletedAt, deviceId, groupId],
      );
    }
    await database.customStatement(
      'UPDATE activities SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? '
      'WHERE project_id IN ($projectIds)',
      <Object?>[deletedAt, deletedAt, deviceId, groupId],
    );
    for (final table in <String>[
      'project_articulating_axes',
      'project_formative_fields',
      'project_grades',
    ]) {
      await database.customStatement(
        'UPDATE $table SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? '
        'WHERE project_id IN ($projectIds)',
        <Object?>[deletedAt, deletedAt, deviceId, groupId],
      );
    }
    await database.customStatement(
      'UPDATE projects SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? WHERE group_id = ?',
      <Object?>[deletedAt, deletedAt, deviceId, groupId],
    );
    await database.customStatement(
      'UPDATE attendance_entries SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? '
      'WHERE attendance_day_id IN (SELECT id FROM attendance_days WHERE group_id = ?)',
      <Object?>[deletedAt, deletedAt, deviceId, groupId],
    );
    await database.customStatement(
      'UPDATE attendance_days SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? WHERE group_id = ?',
      <Object?>[deletedAt, deletedAt, deviceId, groupId],
    );
    await database.customStatement(
      'UPDATE enrollments SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? WHERE group_id = ?',
      <Object?>[deletedAt, deletedAt, deviceId, groupId],
    );
    await database.customStatement(
      'UPDATE group_grades SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? WHERE group_id = ?',
      <Object?>[deletedAt, deletedAt, deviceId, groupId],
    );
    await database.customStatement(
      'UPDATE teaching_groups SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? WHERE id = ?',
      <Object?>[deletedAt, deletedAt, deviceId, groupId],
    );
  }

  Future<void> _deleteOrphanStudents(
    DateTime timestamp,
    String? deviceId,
  ) async {
    final deletedAt = timestamp.millisecondsSinceEpoch;
    const orphanStudents = '''
      SELECT s.id FROM students s
      WHERE NOT EXISTS (
        SELECT 1 FROM enrollments e WHERE e.student_id = s.id AND e.deleted_at IS NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM attendance_entries ae WHERE ae.student_id = s.id AND ae.deleted_at IS NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM activity_roster ar WHERE ar.student_id = s.id AND ar.deleted_at IS NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM activity_evaluations av WHERE av.student_id = s.id AND av.deleted_at IS NULL
      )
      AND s.deleted_at IS NULL
    ''';
    await database.customStatement(
      'UPDATE student_record_entries SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? '
      'WHERE student_id IN ($orphanStudents)',
      <Object?>[deletedAt, deletedAt, deviceId],
    );
    await database.customStatement(
      'UPDATE literacy_assessments SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? '
      'WHERE student_id IN ($orphanStudents)',
      <Object?>[deletedAt, deletedAt, deviceId],
    );
    await database.customStatement(
      'UPDATE student_records SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? '
      'WHERE student_id IN ($orphanStudents)',
      <Object?>[deletedAt, deletedAt, deviceId],
    );
    await database.customStatement(
      'UPDATE students SET deleted_at = ?, updated_at = ?, '
      'updated_by_device_id = ? '
      'WHERE id IN ($orphanStudents)',
      <Object?>[deletedAt, deletedAt, deviceId],
    );
  }

  Future<TeachingGroup> _toDomain(TeachingGroupRow row) async {
    final gradeRows =
        await (database.select(database.groupGrades)..where(
              (table) =>
                  table.groupId.equals(row.id) & table.deletedAt.isNull(),
            ))
            .get();

    return TeachingGroup(
      id: row.id,
      schoolId: row.schoolId,
      schoolYearId: row.schoolYearId,
      name: row.name,
      grades: gradeRows.map((gradeRow) => gradeRow.grade).toSet(),
      shift: row.shift,
      schedule: _readSchedule(row),
      contract: _readContract(row),
      teachingRole: row.teachingRole,
    );
  }

  ClassSchedule? _readSchedule(TeachingGroupRow row) {
    final startsAt = row.scheduleStartMinutes;
    final endsAt = row.scheduleEndMinutes;

    if (startsAt == null && endsAt == null) return null;
    if (startsAt == null || endsAt == null) {
      throw StateError(
        'Persisted teaching-group schedule must contain both boundaries.',
      );
    }

    return ClassSchedule(startsAtMinutes: startsAt, endsAtMinutes: endsAt);
  }

  TeachingContract? _readContract(TeachingGroupRow row) {
    final startsOn = row.contractStartsOn;
    final endsOn = row.contractEndsOn;

    if (startsOn == null && endsOn == null) return null;
    if (startsOn == null || endsOn == null) {
      throw StateError(
        'Persisted teaching-group contract must contain both boundaries.',
      );
    }

    return TeachingContract(startsOn: startsOn, endsOn: endsOn);
  }
}
