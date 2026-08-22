import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/project/activity.dart';

enum EvaluationViolation { activityMismatch, studentNotApplicable }

abstract final class EvaluationPolicy {
  static Set<EvaluationViolation> validate({
    required ActivityEvaluation evaluation,
    required Activity activity,
  }) {
    final violations = <EvaluationViolation>{};

    if (evaluation.activityId != activity.id) {
      violations.add(EvaluationViolation.activityMismatch);
    }
    if (!activity.isApplicableTo(evaluation.studentId)) {
      violations.add(EvaluationViolation.studentNotApplicable);
    }

    return Set<EvaluationViolation>.unmodifiable(violations);
  }
}
