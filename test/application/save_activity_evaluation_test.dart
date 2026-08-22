import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _ActivityRepository activityRepository;
  late _EvaluationRepository evaluationRepository;
  late SaveActivityEvaluation useCase;

  setUp(() {
    activityRepository = _ActivityRepository(
      Activity(
        id: 'activity-1',
        projectId: 'project-1',
        title: 'Actividad',
        targetGrades: <PrimaryGrade>{PrimaryGrade.first},
        roster: const <ActivityParticipant>[
          ActivityParticipant(
            studentId: 'student-1',
            grade: PrimaryGrade.first,
          ),
        ],
      ),
    );
    evaluationRepository = _EvaluationRepository();
    useCase = SaveActivityEvaluation(
      activityRepository: activityRepository,
      evaluationRepository: evaluationRepository,
    );
  });

  test('persists evaluation for a student in the historical roster', () async {
    final evaluation = ActivityEvaluation(
      activityId: 'activity-1',
      studentId: 'student-1',
      deliveryStatus: DeliveryStatus.delivered,
    );

    await useCase(evaluation);

    expect(evaluationRepository.saved, same(evaluation));
  });

  test(
    'rejects evaluation for a student outside the historical roster',
    () async {
      final evaluation = ActivityEvaluation(
        activityId: 'activity-1',
        studentId: 'student-2',
        deliveryStatus: DeliveryStatus.pending,
      );

      await expectLater(useCase(evaluation), throwsA(isA<StateError>()));
      expect(evaluationRepository.saved, isNull);
    },
  );
}

final class _ActivityRepository implements ActivityRepository {
  _ActivityRepository(this.activity);

  final Activity activity;

  @override
  Future<Activity?> findById(String id) async =>
      id == activity.id ? activity : null;

  @override
  Future<List<Activity>> listForProject(String projectId) async =>
      projectId == activity.projectId ? <Activity>[activity] : <Activity>[];

  @override
  Future<void> save(Activity activity) async {}
}

final class _EvaluationRepository implements EvaluationRepository {
  ActivityEvaluation? saved;

  @override
  Future<ActivityEvaluation?> find({
    required String activityId,
    required String studentId,
  }) async => null;

  @override
  Future<List<ActivityEvaluation>> listForActivity(String activityId) async =>
      const <ActivityEvaluation>[];

  @override
  Future<List<ActivityEvaluation>> listForStudent(String studentId) async =>
      const <ActivityEvaluation>[];

  @override
  Future<void> save(ActivityEvaluation evaluation) async {
    saved = evaluation;
  }
}
