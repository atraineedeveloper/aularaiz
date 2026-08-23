import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/evaluation/evaluation_policy.dart';

final class SaveActivityEvaluation {
  SaveActivityEvaluation({
    required ActivityRepository activityRepository,
    required EvaluationRepository evaluationRepository,
  }) : _activityRepository = activityRepository,
       _evaluationRepository = evaluationRepository;

  final ActivityRepository _activityRepository;
  final EvaluationRepository _evaluationRepository;

  Future<ActivityEvaluation> call({
    required String activityId,
    required String studentId,
    required DeliveryStatus deliveryStatus,
    AchievementLevel? achievement,
    String? observation,
  }) async {
    final activity = await _activityRepository.findById(activityId);
    if (activity == null) {
      throw StateError('Activity does not exist.');
    }

    final evaluation = ActivityEvaluation(
      activityId: activityId,
      studentId: studentId,
      deliveryStatus: deliveryStatus,
      achievement: achievement,
      observation: observation,
    );
    final violations = EvaluationPolicy.validate(
      evaluation: evaluation,
      activity: activity,
    );
    if (violations.isNotEmpty) {
      throw StateError(
        'Evaluation violates historical activity applicability: '
        '${violations.map((value) => value.name).join(', ')}.',
      );
    }

    await _evaluationRepository.save(evaluation);
    return evaluation;
  }
}
