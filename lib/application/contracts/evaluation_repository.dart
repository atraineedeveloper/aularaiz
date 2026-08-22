import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';

abstract interface class EvaluationRepository {
  Future<ActivityEvaluation?> find({
    required String activityId,
    required String studentId,
  });

  Future<List<ActivityEvaluation>> listForActivity(String activityId);

  Future<List<ActivityEvaluation>> listForStudent(String studentId);

  Future<void> save(ActivityEvaluation evaluation);
}
