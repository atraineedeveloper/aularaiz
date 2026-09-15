import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:drift/drift.dart';

final class DriftSchoolSetupRepository
    implements
        SchoolSetupRepository,
        EditableSchoolSetupRepository,
        DeletableSchoolSetupRepository,
        SchoolYearStarterRepository {
  DriftSchoolSetupRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<bool> hasInitialSetup() async => (await listSetups()).isNotEmpty;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async {
    final setups = await listSetups();
    return setups.isEmpty ? null : setups.first;
  }

  @override
  Future<List<InitialSchoolSetup>> listSetups() async {
    final contexts = await (database.select(
      database.schoolContexts,
    )..where((table) => table.deletedAt.isNull())).get();
    final result = <InitialSchoolSetup>[];
    for (final context in contexts) {
      final setup = await _loadContext(
        schoolId: context.schoolId,
        schoolYearId: context.schoolYearId,
      );
      if (setup != null) result.add(setup);
    }
    result.sort((left, right) => left.school.name.compareTo(right.school.name));
    return List<InitialSchoolSetup>.unmodifiable(result);
  }

  @override
  Future<InitialSchoolSetup?> loadForSchool(String schoolId) async {
    final context =
        await (database.select(database.schoolContexts)
              ..where((table) => table.schoolId.equals(schoolId))
              ..where((table) => table.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (context == null) return null;
    return _loadContext(
      schoolId: context.schoolId,
      schoolYearId: context.schoolYearId,
    );
  }

  @override
  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  }) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      await database
          .into(database.schools)
          .insert(
            SchoolsCompanion(
              id: Value(school.id),
              name: Value(school.name),
              cct: Value(school.cct),
              organization: Value(school.organization),
              state: Value(school.state),
              municipality: Value(school.municipality),
              locality: Value(school.locality),
              schoolZone: Value(school.schoolZone),
              schoolSector: Value(school.schoolSector),
              supervisorName: Value(school.supervisorName),
              leadershipName: Value(school.leadershipName),
              leadershipRole: Value(school.leadershipRole),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );

      await database
          .into(database.schoolYears)
          .insert(
            SchoolYearsCompanion(
              id: Value(schoolYear.id),
              label: Value(schoolYear.label),
              startsOn: Value(schoolYear.startsOn),
              endsOn: Value(schoolYear.endsOn),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );

      await database
          .into(database.schoolContexts)
          .insert(
            SchoolContextsCompanion(
              schoolId: Value(school.id),
              schoolYearId: Value(schoolYear.id),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );
    });
  }

  @override
  Future<void> startSchoolYear({
    required String schoolId,
    required SchoolYear schoolYear,
  }) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      await database
          .into(database.schoolYears)
          .insert(
            SchoolYearsCompanion(
              id: Value(schoolYear.id),
              label: Value(schoolYear.label),
              startsOn: Value(schoolYear.startsOn),
              endsOn: Value(schoolYear.endsOn),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );

      await database
          .into(database.schoolContexts)
          .insertOnConflictUpdate(
            SchoolContextsCompanion(
              schoolId: Value(schoolId),
              schoolYearId: Value(schoolYear.id),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );
    });
  }

  @override
  Future<void> updateSchool(School school) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    final updated =
        await (database.update(
          database.schools,
        )..where((table) => table.id.equals(school.id))).write(
          SchoolsCompanion(
            name: Value(school.name),
            cct: Value(school.cct),
            organization: Value(school.organization),
            state: Value(school.state),
            municipality: Value(school.municipality),
            locality: Value(school.locality),
            schoolZone: Value(school.schoolZone),
            schoolSector: Value(school.schoolSector),
            supervisorName: Value(school.supervisorName),
            leadershipName: Value(school.leadershipName),
            leadershipRole: Value(school.leadershipRole),
            updatedAt: SyncMetadataValues.updated(timestamp),
            updatedByDeviceId: deviceId,
          ),
        );
    if (updated != 1) {
      throw StateError('School does not exist.');
    }
  }

  @override
  Future<void> deleteSchool(String schoolId) async {
    await database.transaction(() async {
      final timestamp = SyncMetadataValues.now();
      final deletedAt = timestamp.millisecondsSinceEpoch;
      final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
      final deviceIdValue = deviceId.value;
      final school =
          await (database.select(database.schools)
                ..where(
                  (table) =>
                      table.id.equals(schoolId) & table.deletedAt.isNull(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (school == null) throw StateError('School does not exist.');

      final contextRows =
          await (database.select(database.schoolContexts)..where(
                (table) =>
                    table.schoolId.equals(schoolId) & table.deletedAt.isNull(),
              ))
              .get();
      final schoolYearIds = contextRows.map((row) => row.schoolYearId).toSet();

      const groupIds = 'SELECT id FROM teaching_groups WHERE school_id = ?';
      const projectIds =
          '''
        SELECT id FROM projects WHERE group_id IN ($groupIds)
      ''';
      const activityIds =
          '''
        SELECT id FROM activities WHERE project_id IN ($projectIds)
      ''';

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
          <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
        );
      }
      await database.customStatement(
        'UPDATE activities SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? '
        'WHERE project_id IN ($projectIds)',
        <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
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
          <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
        );
      }
      await database.customStatement(
        'UPDATE projects SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? '
        'WHERE group_id IN ($groupIds)',
        <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
      );
      await database.customStatement(
        'UPDATE attendance_entries SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? '
        'WHERE attendance_day_id IN (SELECT id FROM attendance_days WHERE group_id IN ($groupIds))',
        <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
      );
      await database.customStatement(
        'UPDATE attendance_days SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? '
        'WHERE group_id IN ($groupIds)',
        <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
      );
      await database.customStatement(
        'UPDATE enrollments SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? '
        'WHERE group_id IN ($groupIds)',
        <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
      );
      await database.customStatement(
        'UPDATE group_grades SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? '
        'WHERE group_id IN ($groupIds)',
        <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
      );
      await database.customStatement(
        'UPDATE teaching_groups SET deleted_at = ?, updated_at = ?, '
        'updated_by_device_id = ? WHERE school_id = ?',
        <Object?>[deletedAt, deletedAt, deviceIdValue, schoolId],
      );
      await (database.update(
        database.schoolContexts,
      )..where((table) => table.schoolId.equals(schoolId))).write(
        SchoolContextsCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await (database.update(
        database.schools,
      )..where((table) => table.id.equals(schoolId))).write(
        SchoolsCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );

      await _deleteOrphanStudents(timestamp, deviceIdValue);
      for (final schoolYearId in schoolYearIds) {
        final contextReference =
            await (database.select(database.schoolContexts)
                  ..where(
                    (table) =>
                        table.schoolYearId.equals(schoolYearId) &
                        table.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        final groupReference =
            await (database.select(database.teachingGroups)
                  ..where(
                    (table) =>
                        table.schoolYearId.equals(schoolYearId) &
                        table.deletedAt.isNull(),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (contextReference == null && groupReference == null) {
          await (database.update(
            database.schoolYears,
          )..where((table) => table.id.equals(schoolYearId))).write(
            SchoolYearsCompanion(
              deletedAt: SyncMetadataValues.deleted(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );
        }
      }
    });
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

  Future<InitialSchoolSetup?> _loadContext({
    required String schoolId,
    required String schoolYearId,
  }) async {
    final schoolRow =
        await (database.select(database.schools)
              ..where(
                (table) => table.id.equals(schoolId) & table.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    final schoolYearRow =
        await (database.select(database.schoolYears)
              ..where(
                (table) =>
                    table.id.equals(schoolYearId) & table.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    if (schoolRow == null || schoolYearRow == null) return null;

    return (
      school: School(
        id: schoolRow.id,
        name: schoolRow.name,
        cct: schoolRow.cct,
        organization: schoolRow.organization,
        state: schoolRow.state,
        municipality: schoolRow.municipality,
        locality: schoolRow.locality,
        schoolZone: schoolRow.schoolZone,
        schoolSector: schoolRow.schoolSector,
        supervisorName: schoolRow.supervisorName,
        leadershipName: schoolRow.leadershipName,
        leadershipRole: schoolRow.leadershipRole,
      ),
      schoolYear: SchoolYear(
        id: schoolYearRow.id,
        label: schoolYearRow.label,
        startsOn: schoolYearRow.startsOn,
        endsOn: schoolYearRow.endsOn,
      ),
    );
  }
}
