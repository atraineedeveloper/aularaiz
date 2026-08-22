import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/evaluation/evaluation_state.dart';

final class ActivityEvaluation {
  ActivityEvaluation({
    required this.activityId,
    required this.studentId,
    required this.deliveryStatus,
    this.achievement,
    String? observation,
  }) : observation = _normalizeOptionalText(observation) {
    if (activityId.trim().isEmpty) {
      throw ArgumentError.value(
        activityId,
        'activityId',
        'Evaluation activity id cannot be empty.',
      );
    }
    if (studentId.trim().isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Evaluation student id cannot be empty.',
      );
    }
    if (deliveryStatus != DeliveryStatus.delivered && achievement != null) {
      throw ArgumentError.value(
        achievement,
        'achievement',
        'Achievement is valid only for delivered work.',
      );
    }
  }

  final String activityId;
  final String studentId;
  final DeliveryStatus deliveryStatus;
  final AchievementLevel? achievement;
  final String? observation;

  EvaluationState get state {
    return switch (deliveryStatus) {
      DeliveryStatus.pending => EvaluationState.pendingDeliveryDecision,
      DeliveryStatus.notDelivered => EvaluationState.notDelivered,
      DeliveryStatus.delivered =>
        achievement == null
            ? EvaluationState.deliveredAwaitingEvaluation
            : EvaluationState.deliveredAndEvaluated,
    };
  }

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
