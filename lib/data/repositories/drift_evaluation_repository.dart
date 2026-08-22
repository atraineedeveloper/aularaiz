import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:drift/drift.dart';

final class DriftEvaluationRepository implements EvaluationRepository {
  DriftEvaluationRepository(this.database);

  final AppDatabase database;

  @override
  Future<ActivityEvaluation?> find({
    required String activityId,
    required String studentId,
  }) async {
    final row =
        await (database.select(database.activityEvaluations)
              ..where(
                (table) =>
                    table.activityId.equals(activityId) &
                    table.studentId.equals(studentId),
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
              ..orderBy([(table) => OrderingTerm.asc(table.studentId)]))
            .get();
    return List<ActivityEvaluation>.unmodifiable(rows.map(_toDomain));
  }

  @override
  Future<List<ActivityEvaluation>> listForStudent(String studentId) async {
    final rows =
        await (database.select(database.activityEvaluations)
              ..where((table) => table.studentId.equals(studentId))
              ..orderBy([(table) => OrderingTerm.asc(table.activityId)]))
            .get();
    return List<ActivityEvaluation>.unmodifiable(rows.map(_toDomain));
  }

  @override
  Future<void> save(ActivityEvaluation evaluation) async {
    await database
        .into(database.activityEvaluations)
        .insertOnConflictUpdate(
          ActivityEvaluationsCompanion(
            activityId: Value(evaluation.activityId),
            studentId: Value(evaluation.studentId),
            deliveryStatus: Value(evaluation.deliveryStatus),
            achievement: Value(evaluation.achievement),
            observation: Value(evaluation.observation),
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
