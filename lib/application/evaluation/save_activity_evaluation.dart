import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/evaluation_policy.dart';

final class SaveActivityEvaluation {
  SaveActivityEvaluation({
    required ActivityRepository activityRepository,
    required EvaluationRepository evaluationRepository,
  }) : _activityRepository = activityRepository,
       _evaluationRepository = evaluationRepository;

  final ActivityRepository _activityRepository;
  final EvaluationRepository _evaluationRepository;

  Future<void> call(ActivityEvaluation evaluation) async {
    final activity = await _activityRepository.findById(evaluation.activityId);
    if (activity == null) {
      throw StateError('Activity does not exist.');
    }

    final violations = EvaluationPolicy.validate(
      evaluation: evaluation,
      activity: activity,
    );
    if (violations.isNotEmpty) {
      throw StateError('Evaluation violates the activity roster.');
    }

    await _evaluationRepository.save(evaluation);
  }
}
