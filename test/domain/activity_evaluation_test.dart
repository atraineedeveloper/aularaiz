import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/evaluation/evaluation_policy.dart';
import 'package:aularaiz/domain/evaluation/evaluation_state.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final activity = Activity(
    id: 'activity-1',
    projectId: 'project-1',
    title: 'Producto final',
    targetGrades: <PrimaryGrade>{PrimaryGrade.second},
    roster: <ActivityParticipant>[
      ActivityParticipant(
        studentId: 'student-1',
        grade: PrimaryGrade.second,
      ),
    ],
  );

  test('evaluation exposes the four required semantic states', () {
    expect(
      ActivityEvaluation(
        activityId: activity.id,
        studentId: 'student-1',
        deliveryStatus: DeliveryStatus.pending,
      ).state,
      EvaluationState.pendingDeliveryDecision,
    );
    expect(
      ActivityEvaluation(
        activityId: activity.id,
        studentId: 'student-1',
        deliveryStatus: DeliveryStatus.delivered,
      ).state,
      EvaluationState.deliveredAwaitingEvaluation,
    );
    expect(
      ActivityEvaluation(
        activityId: activity.id,
        studentId: 'student-1',
        deliveryStatus: DeliveryStatus.notDelivered,
      ).state,
      EvaluationState.notDelivered,
    );
    expect(
      ActivityEvaluation(
        activityId: activity.id,
        studentId: 'student-1',
        deliveryStatus: DeliveryStatus.delivered,
        achievement: AchievementLevel.mastered,
      ).state,
      EvaluationState.deliveredAndEvaluated,
    );
  });

  test('non-delivery cannot carry an achievement level', () {
    expect(
      () => ActivityEvaluation(
        activityId: activity.id,
        studentId: 'student-1',
        deliveryStatus: DeliveryStatus.notDelivered,
        achievement: AchievementLevel.requiresSupport,
      ),
      throwsArgumentError,
    );
  });

  test('pending delivery cannot carry an achievement level', () {
    expect(
      () => ActivityEvaluation(
        activityId: activity.id,
        studentId: 'student-1',
        deliveryStatus: DeliveryStatus.pending,
        achievement: AchievementLevel.sufficient,
      ),
      throwsArgumentError,
    );
  });

  test('evaluation policy rejects students outside historical roster', () {
    final evaluation = ActivityEvaluation(
      activityId: activity.id,
      studentId: 'student-2',
      deliveryStatus: DeliveryStatus.delivered,
    );

    expect(
      EvaluationPolicy.validate(evaluation: evaluation, activity: activity),
      contains(EvaluationViolation.studentNotApplicable),
    );
  });

  test('blank observations are normalized instead of persisted as content', () {
    final evaluation = ActivityEvaluation(
      activityId: activity.id,
      studentId: 'student-1',
      deliveryStatus: DeliveryStatus.delivered,
      observation: '   ',
    );

    expect(evaluation.observation, isNull);
  });
}
