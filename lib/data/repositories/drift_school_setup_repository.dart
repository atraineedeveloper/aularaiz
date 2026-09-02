import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:drift/drift.dart';

final class DriftSchoolSetupRepository
    implements
        SchoolSetupRepository,
        EditableSchoolSetupRepository,
        DeletableSchoolSetupRepository,
        SchoolYearStarterRepository {
  DriftSchoolSetupRepository(this.database);

  final AppDatabase database;

  @override
  Future<bool> hasInitialSetup() async => (await listSetups()).isNotEmpty;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async {
    final setups = await listSetups();
    return setups.isEmpty ? null : setups.first;
  }

  @override
  Future<List<InitialSchoolSetup>> listSetups() async {
    final contexts = await database.select(database.schoolContexts).get();
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
            ),
          );

      await database
          .into(database.schoolContexts)
          .insert(
            SchoolContextsCompanion(
              schoolId: Value(school.id),
              schoolYearId: Value(schoolYear.id),
            ),
          );
    });
  }

  @override
  Future<void> startSchoolYear({
    required String schoolId,
    required SchoolYear schoolYear,
  }) async {
    await database.transaction(() async {
      await database
          .into(database.schoolYears)
          .insert(
            SchoolYearsCompanion(
              id: Value(schoolYear.id),
              label: Value(schoolYear.label),
              startsOn: Value(schoolYear.startsOn),
              endsOn: Value(schoolYear.endsOn),
            ),
          );

      await database
          .into(database.schoolContexts)
          .insertOnConflictUpdate(
            SchoolContextsCompanion(
              schoolId: Value(schoolId),
              schoolYearId: Value(schoolYear.id),
            ),
          );
    });
  }

  @override
  Future<void> updateSchool(School school) async {
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
          ),
        );
    if (updated != 1) {
      throw StateError('School does not exist.');
    }
  }

  @override
  Future<void> deleteSchool(String schoolId) async {
    await database.transaction(() async {
      final school =
          await (database.select(database.schools)
                ..where((table) => table.id.equals(schoolId))
                ..limit(1))
              .getSingleOrNull();
      if (school == null) throw StateError('School does not exist.');

      final contextRows = await (database.select(
        database.schoolContexts,
      )..where((table) => table.schoolId.equals(schoolId))).get();
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
          'DELETE FROM $table WHERE activity_id IN ($activityIds)',
          <Object?>[schoolId],
        );
      }
      await database.customStatement(
        'DELETE FROM activities WHERE project_id IN ($projectIds)',
        <Object?>[schoolId],
      );
      for (final table in <String>[
        'project_articulating_axes',
        'project_formative_fields',
        'project_grades',
      ]) {
        await database.customStatement(
          'DELETE FROM $table WHERE project_id IN ($projectIds)',
          <Object?>[schoolId],
        );
      }
      await database.customStatement(
        'DELETE FROM projects WHERE group_id IN ($groupIds)',
        <Object?>[schoolId],
      );
      await database.customStatement(
        'DELETE FROM attendance_days WHERE group_id IN ($groupIds)',
        <Object?>[schoolId],
      );
      await database.customStatement(
        'DELETE FROM enrollments WHERE group_id IN ($groupIds)',
        <Object?>[schoolId],
      );
      await database.customStatement(
        'DELETE FROM group_grades WHERE group_id IN ($groupIds)',
        <Object?>[schoolId],
      );
      await database.customStatement(
        'DELETE FROM teaching_groups WHERE school_id = ?',
        <Object?>[schoolId],
      );
      await (database.delete(
        database.schoolContexts,
      )..where((table) => table.schoolId.equals(schoolId))).go();
      await (database.delete(
        database.schools,
      )..where((table) => table.id.equals(schoolId))).go();

      await _deleteOrphanStudents();
      for (final schoolYearId in schoolYearIds) {
        final contextReference =
            await (database.select(database.schoolContexts)
                  ..where((table) => table.schoolYearId.equals(schoolYearId))
                  ..limit(1))
                .getSingleOrNull();
        final groupReference =
            await (database.select(database.teachingGroups)
                  ..where((table) => table.schoolYearId.equals(schoolYearId))
                  ..limit(1))
                .getSingleOrNull();
        if (contextReference == null && groupReference == null) {
          await (database.delete(
            database.schoolYears,
          )..where((table) => table.id.equals(schoolYearId))).go();
        }
      }
    });
  }

  Future<void> _deleteOrphanStudents() async {
    const orphanStudents = '''
      SELECT s.id FROM students s
      WHERE NOT EXISTS (
        SELECT 1 FROM enrollments e WHERE e.student_id = s.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM attendance_entries ae WHERE ae.student_id = s.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM activity_roster ar WHERE ar.student_id = s.id
      )
      AND NOT EXISTS (
        SELECT 1 FROM activity_evaluations av WHERE av.student_id = s.id
      )
    ''';
    await database.customStatement(
      'DELETE FROM student_record_entries WHERE student_id IN ($orphanStudents)',
    );
    await database.customStatement(
      'DELETE FROM student_records WHERE student_id IN ($orphanStudents)',
    );
    await database.customStatement(
      'DELETE FROM students WHERE id IN ($orphanStudents)',
    );
  }

  Future<InitialSchoolSetup?> _loadContext({
    required String schoolId,
    required String schoolYearId,
  }) async {
    final schoolRow =
        await (database.select(database.schools)
              ..where((table) => table.id.equals(schoolId))
              ..limit(1))
            .getSingleOrNull();
    final schoolYearRow =
        await (database.select(database.schoolYears)
              ..where((table) => table.id.equals(schoolYearId))
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
