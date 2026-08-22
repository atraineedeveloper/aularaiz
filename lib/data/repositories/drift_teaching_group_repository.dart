import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:drift/drift.dart';

final class DriftTeachingGroupRepository implements TeachingGroupRepository {
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
}
