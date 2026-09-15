import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:drift/drift.dart';

final class DriftActivityRepository
    implements ActivityRepository, DeletableActivityRepository {
  DriftActivityRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<Activity?> findById(String id) async {
    final row =
        await (database.select(database.activities)
              ..where((table) => table.id.equals(id))
              ..where((table) => table.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Activity>> listForProject(String projectId) async {
    final rows =
        await (database.select(database.activities)
              ..where((table) => table.projectId.equals(projectId))
              ..where((table) => table.deletedAt.isNull())
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
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      await database
          .into(database.activities)
          .insertOnConflictUpdate(
            ActivitiesCompanion(
              id: Value(activity.id),
              projectId: Value(activity.projectId),
              identifier: Value(activity.identifier),
              title: Value(activity.title),
              description: Value(activity.description),
              occursOn: Value(activity.occursOn),
              generalObservations: Value(activity.generalObservations),
              deletedAt: const Value(null),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );
      await database
          .into(database.activityFormativeFields)
          .insertOnConflictUpdate(
            ActivityFormativeFieldsCompanion(
              activityId: Value(activity.id),
              formativeField: Value(activity.formativeField),
              deletedAt: const Value(null),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );
      await (database.update(
        database.activityRoster,
      )..where((table) => table.activityId.equals(activity.id))).write(
        ActivityRosterCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await (database.update(
        database.activityGrades,
      )..where((table) => table.activityId.equals(activity.id))).write(
        ActivityGradesCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await database.batch((batch) {
        for (final grade in activity.targetGrades) {
          batch.insert(
            database.activityGrades,
            ActivityGradesCompanion(
              activityId: Value(activity.id),
              grade: Value(grade),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              deletedAt: const Value(null),
              updatedByDeviceId: deviceId,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final participant in activity.roster.values) {
          batch.insert(
            database.activityRoster,
            ActivityRosterCompanion(
              activityId: Value(activity.id),
              studentId: Value(participant.studentId),
              grade: Value(participant.grade),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              deletedAt: const Value(null),
              updatedByDeviceId: deviceId,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      await (database.update(
        database.activityEvaluations,
      )..where((table) => table.activityId.equals(activityId))).write(
        ActivityEvaluationsCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await (database.update(
        database.activityRoster,
      )..where((table) => table.activityId.equals(activityId))).write(
        ActivityRosterCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await (database.update(
        database.activityGrades,
      )..where((table) => table.activityId.equals(activityId))).write(
        ActivityGradesCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await (database.update(
        database.activityFormativeFields,
      )..where((table) => table.activityId.equals(activityId))).write(
        ActivityFormativeFieldsCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      final deleted =
          await (database.update(
            database.activities,
          )..where((table) => table.id.equals(activityId))).write(
            ActivitiesCompanion(
              deletedAt: SyncMetadataValues.deleted(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );
      if (deleted != 1) {
        throw StateError('Activity does not exist.');
      }
    });
  }

  Future<Activity> _toDomain(ActivityRow row) async {
    final grades =
        await (database.select(database.activityGrades)..where(
              (table) =>
                  table.activityId.equals(row.id) & table.deletedAt.isNull(),
            ))
            .get();
    final roster =
        await (database.select(database.activityRoster)..where(
              (table) =>
                  table.activityId.equals(row.id) & table.deletedAt.isNull(),
            ))
            .get();
    final fieldRow =
        await (database.select(database.activityFormativeFields)
              ..where((table) => table.activityId.equals(row.id))
              ..where((table) => table.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    final formativeField = fieldRow?.formativeField ?? await _legacyField(row);
    return Activity(
      id: row.id,
      projectId: row.projectId,
      identifier: row.identifier,
      title: row.title,
      description: row.description,
      occursOn: row.occursOn,
      generalObservations: row.generalObservations,
      formativeField: formativeField,
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

  Future<FormativeField> _legacyField(ActivityRow row) async {
    final project =
        await (database.select(database.projects)
              ..where((table) => table.id.equals(row.projectId))
              ..limit(1))
            .getSingleOrNull();
    return project?.formativeField ?? FormativeField.unspecified;
  }
}
