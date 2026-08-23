import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Activity activity;
  late _MemoryEvaluationRepository evaluationRepository;
  late SaveActivityEvaluation useCase;

  setUp(() {
    activity = Activity(
      id: 'activity-1',
      projectId: 'project-1',
      title: 'Producto final',
      formativeField: FormativeField.languages,
      targetGrades: {PrimaryGrade.fifth},
      roster: [
        ActivityParticipant(
          studentId: 'student-applicable',
          grade: PrimaryGrade.fifth,
        ),
      ],
    );
    evaluationRepository = _MemoryEvaluationRepository();
    useCase = SaveActivityEvaluation(
      activityRepository: _MemoryActivityRepository(activity),
      evaluationRepository: evaluationRepository,
    );
  });

  test('saves delivered achievement for historical participant', () async {
    final result = await useCase(
      activityId: activity.id,
      studentId: 'student-applicable',
      deliveryStatus: DeliveryStatus.delivered,
      achievement: AchievementLevel.sufficient,
      observation: '  Avanza con apoyo visual.  ',
    );

    expect(result.deliveryStatus, DeliveryStatus.delivered);
    expect(result.achievement, AchievementLevel.sufficient);
    expect(result.observation, 'Avanza con apoyo visual.');
    expect(evaluationRepository.saved, same(result));
  });

  test('rejects student outside frozen historical roster', () async {
    expect(
      () => useCase(
        activityId: activity.id,
        studentId: 'student-added-later',
        deliveryStatus: DeliveryStatus.delivered,
        achievement: AchievementLevel.mastered,
      ),
      throwsStateError,
    );

    expect(evaluationRepository.saved, isNull);
  });

  test('not delivered cannot carry a low achievement level', () async {
    expect(
      () => useCase(
        activityId: activity.id,
        studentId: 'student-applicable',
        deliveryStatus: DeliveryStatus.notDelivered,
        achievement: AchievementLevel.requiresSupport,
      ),
      throwsArgumentError,
    );

    expect(evaluationRepository.saved, isNull);
  });
}

final class _MemoryActivityRepository implements ActivityRepository {
  _MemoryActivityRepository(this.activity);

  final Activity activity;

  @override
  Future<Activity?> findById(String id) async =>
      id == activity.id ? activity : null;

  @override
  Future<List<Activity>> listForProject(String projectId) async => [activity];

  @override
  Future<void> save(Activity activity) async {}
}

final class _MemoryEvaluationRepository implements EvaluationRepository {
  ActivityEvaluation? saved;

  @override
  Future<ActivityEvaluation?> find(String activityId, String studentId) async {
    final value = saved;
    if (value == null) return null;
    return value.activityId == activityId && value.studentId == studentId
        ? value
        : null;
  }

  @override
  Future<List<ActivityEvaluation>> listForActivity(String activityId) async {
    final value = saved;
    return value != null && value.activityId == activityId ? [value] : const [];
  }

  @override
  Future<List<ActivityEvaluation>> listForStudent(String studentId) async {
    final value = saved;
    return value != null && value.studentId == studentId ? [value] : const [];
  }

  @override
  Future<void> save(ActivityEvaluation evaluation) async {
    saved = evaluation;
  }
}
