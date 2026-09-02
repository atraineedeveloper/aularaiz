import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:drift/drift.dart';

final class DriftTeachingGroupRepository
    implements TeachingGroupRepository, DeletableTeachingGroupRepository {
  DriftTeachingGroupRepository(this.database);

  final AppDatabase database;

  @override
  Future<TeachingGroup?> findById(String id) async {
    final row = await (database.select(
      database.teachingGroups,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    if (row == null) return null;
    return _toDomain(row);
  }

  @override
  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId) async {
    final rows = await (database.select(
      database.teachingGroups,
    )..where((table) => table.schoolYearId.equals(schoolYearId))).get();
    final groups = <TeachingGroup>[];

    for (final row in rows) {
      groups.add(await _toDomain(row));
    }

    groups.sort((left, right) => left.name.compareTo(right.name));
    return groups;
  }

  @override
  Future<void> save(TeachingGroup group) async {
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
            ),
          );

      final existingRows = await (database.select(
        database.groupGrades,
      )..where((table) => table.groupId.equals(group.id))).get();
      final existingGrades = existingRows.map((row) => row.grade).toSet();
      final removedGrades = existingGrades.difference(group.grades);
      final addedGrades = group.grades.difference(existingGrades);

      for (final grade in removedGrades) {
        await (database.delete(database.groupGrades)..where(
              (table) =>
                  table.groupId.equals(group.id) &
                  table.grade.equalsValue(grade),
            ))
            .go();
      }

      await database.batch((batch) {
        for (final grade in addedGrades) {
          batch.insert(
            database.groupGrades,
            GroupGradesCompanion(groupId: Value(group.id), grade: Value(grade)),
          );
        }
      });
    });
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await database.transaction(() async {
      final exists =
          await (database.select(database.teachingGroups)
                ..where((table) => table.id.equals(groupId))
                ..limit(1))
              .getSingleOrNull();
      if (exists == null) throw StateError('Teaching group does not exist.');
      await _deleteGroupData(groupId);
      await _deleteOrphanStudents();
    });
  }

  Future<void> _deleteGroupData(String groupId) async {
    const activityIds = '''
      SELECT a.id
      FROM activities a
      INNER JOIN projects p ON p.id = a.project_id
      WHERE p.group_id = ?
    ''';
    const projectIds = 'SELECT id FROM projects WHERE group_id = ?';

    for (final table in <String>[
      'activity_evaluations',
      'activity_roster',
      'activity_grades',
      'activity_formative_fields',
    ]) {
      await database.customStatement(
        'DELETE FROM $table WHERE activity_id IN ($activityIds)',
        <Object?>[groupId],
      );
    }
    await database.customStatement(
      'DELETE FROM activities WHERE project_id IN ($projectIds)',
      <Object?>[groupId],
    );
    for (final table in <String>[
      'project_articulating_axes',
      'project_formative_fields',
      'project_grades',
    ]) {
      await database.customStatement(
        'DELETE FROM $table WHERE project_id IN ($projectIds)',
        <Object?>[groupId],
      );
    }
    await database.customStatement(
      'DELETE FROM projects WHERE group_id = ?',
      <Object?>[groupId],
    );
    await database.customStatement(
      'DELETE FROM attendance_days WHERE group_id = ?',
      <Object?>[groupId],
    );
    await database.customStatement(
      'DELETE FROM enrollments WHERE group_id = ?',
      <Object?>[groupId],
    );
    await database.customStatement(
      'DELETE FROM group_grades WHERE group_id = ?',
      <Object?>[groupId],
    );
    final deleted = await database.customUpdate(
      'DELETE FROM teaching_groups WHERE id = ?',
      variables: <Variable<Object>>[Variable<String>(groupId)],
      updates: {database.teachingGroups},
    );
    if (deleted != 1) throw StateError('Teaching group could not be deleted.');
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

  Future<TeachingGroup> _toDomain(TeachingGroupRow row) async {
    final gradeRows = await (database.select(
      database.groupGrades,
    )..where((table) => table.groupId.equals(row.id))).get();

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
