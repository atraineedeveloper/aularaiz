import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:drift/drift.dart';

final class DriftEvaluationRepository implements EvaluationRepository {
  DriftEvaluationRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<ActivityEvaluation?> find(String activityId, String studentId) async {
    final row =
        await (database.select(database.activityEvaluations)
              ..where(
                (table) =>
                    table.activityId.equals(activityId) &
                    table.studentId.equals(studentId) &
                    table.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<ActivityEvaluation>> listForActivity(String activityId) async {
    final rows =
        await (database.select(database.activityEvaluations)
              ..where((table) => table.activityId.equals(activityId))
              ..where((table) => table.deletedAt.isNull())
              ..orderBy([(table) => OrderingTerm.asc(table.studentId)]))
            .get();
    return List<ActivityEvaluation>.unmodifiable(rows.map(_toDomain));
  }

  @override
  Future<List<ActivityEvaluation>> listForStudent(String studentId) async {
    final rows =
        await (database.select(database.activityEvaluations)
              ..where((table) => table.studentId.equals(studentId))
              ..where((table) => table.deletedAt.isNull())
              ..orderBy([(table) => OrderingTerm.asc(table.activityId)]))
            .get();
    return List<ActivityEvaluation>.unmodifiable(rows.map(_toDomain));
  }

  @override
  Future<void> save(ActivityEvaluation evaluation) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database
        .into(database.activityEvaluations)
        .insertOnConflictUpdate(
          ActivityEvaluationsCompanion(
            activityId: Value(evaluation.activityId),
            studentId: Value(evaluation.studentId),
            deliveryStatus: Value(evaluation.deliveryStatus),
            achievement: Value(evaluation.achievement),
            observation: Value(evaluation.observation),
            deletedAt: const Value(null),
            updatedAt: SyncMetadataValues.updated(timestamp),
            updatedByDeviceId: deviceId,
          ),
        );
  }

  ActivityEvaluation _toDomain(ActivityEvaluationRow row) {
    return ActivityEvaluation(
      activityId: row.activityId,
      studentId: row.studentId,
      deliveryStatus: row.deliveryStatus,
      achievement: row.achievement,
      observation: row.observation,
    );
  }
}
