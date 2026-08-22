import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';

final class DriftTeachingGroupRepository implements TeachingGroupRepository {
  DriftTeachingGroupRepository(this.database);

  final AppDatabase database;

  @override
  Future<TeachingGroup?> findById(String id) async {
    final row = await (database.select(
      database.teachingGroups,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    if (row == null) return null;

    final gradeRows = await (database.select(
      database.groupGrades,
    )..where((table) => table.groupId.equals(id))).get();

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

    return ClassSchedule(
      startsAtMinutes: startsAt,
      endsAtMinutes: endsAt,
    );
  }
}
