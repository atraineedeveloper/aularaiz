import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
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
          ..orderBy([
            (table) => OrderingTerm.asc(table.occursOn),
            (table) => OrderingTerm.asc(table.identifier),
            (table) => OrderingTerm.asc(table.title),
          ]))
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
              identifier: Value(activity.identifier),
              title: Value(activity.title),
              occursOn: Value(activity.occursOn),
            ),
          );
      await database.into(database.activityFormativeFields).insertOnConflictUpdate(
            ActivityFormativeFieldsCompanion(
              activityId: Value(activity.id),
              formativeField: Value(activity.formativeField),
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
            ActivityGradesCompanion(activityId: Value(activity.id), grade: Value(grade)),
          );
        }
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
    final fieldRow = await (database.select(database.activityFormativeFields)
          ..where((table) => table.activityId.equals(row.id))
          ..limit(1))
        .getSingleOrNull();
    final formativeField = fieldRow?.formativeField ?? await _legacyField(row);
    return Activity(
      id: row.id,
      projectId: row.projectId,
      identifier: row.identifier,
      title: row.title,
      occursOn: row.occursOn,
      formativeField: formativeField,
      targetGrades: {for (final grade in grades) grade.grade},
      roster: [
        for (final participant in roster)
          ActivityParticipant(studentId: participant.studentId, grade: participant.grade),
      ],
    );
  }

  Future<FormativeField> _legacyField(ActivityRow row) async {
    final project = await (database.select(database.projects)
          ..where((table) => table.id.equals(row.projectId))
          ..limit(1))
        .getSingleOrNull();
    return project?.formativeField ?? FormativeField.unspecified;
  }
}
