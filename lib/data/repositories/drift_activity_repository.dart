import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:drift/drift.dart';

final class DriftActivityRepository implements ActivityRepository {
  DriftActivityRepository(this.database);

  final AppDatabase database;

  @override
  Future<Activity?> findById(String id) async {
    final row = await (database.select(database.activities)
          ..where((table) => table.id.equals(id))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Activity>> listForProject(String projectId) async {
    final rows = await (database.select(database.activities)
          ..where((table) => table.projectId.equals(projectId))
          ..orderBy([(table) => OrderingTerm.asc(table.title)]))
        .get();
    final result = <Activity>[];
    for (final row in rows) {
      result.add(await _toDomain(row));
    }
    return List<Activity>.unmodifiable(result);
  }

  @override
  Future<void> save(Activity activity) async {
    await database.transaction(() async {
      await database.into(database.activities).insertOnConflictUpdate(
            ActivitiesCompanion(
              id: Value(activity.id),
              projectId: Value(activity.projectId),
              title: Value(activity.title),
            ),
          );
      await (database.delete(database.activityRoster)
            ..where((table) => table.activityId.equals(activity.id)))
          .go();
      await (database.delete(database.activityGrades)
            ..where((table) => table.activityId.equals(activity.id)))
          .go();
      await database.batch((batch) {
        for (final grade in activity.targetGrades) {
          batch.insert(
            database.activityGrades,
            ActivityGradesCompanion(
              activityId: Value(activity.id),
              grade: Value(grade),
            ),
          );
        }
      });
      await database.batch((batch) {
        for (final participant in activity.roster.values) {
          batch.insert(
            database.activityRoster,
            ActivityRosterCompanion(
              activityId: Value(activity.id),
              studentId: Value(participant.studentId),
              grade: Value(participant.grade),
            ),
          );
        }
      });
    });
  }

  Future<Activity> _toDomain(ActivityRow row) async {
    final grades = await (database.select(database.activityGrades)
          ..where((table) => table.activityId.equals(row.id)))
        .get();
    final roster = await (database.select(database.activityRoster)
          ..where((table) => table.activityId.equals(row.id)))
        .get();
    return Activity(
      id: row.id,
      projectId: row.projectId,
      title: row.title,
      targetGrades: {for (final grade in grades) grade.grade},
      roster: [
        for (final participant in roster)
          ActivityParticipant(
            studentId: participant.studentId,
            grade: participant.grade,
          ),
      ],
    );
  }
}
