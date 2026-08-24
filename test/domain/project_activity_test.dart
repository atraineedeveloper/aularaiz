import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/activity_policy.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final project = Project(
    id: 'project-1',
    groupId: 'group-1',
    title: 'Mi comunidad',
    lifecycle: ProjectLifecycle.draft,
    methodology: ProjectMethodology.communityProjects,
    articulatingAxes: <ArticulatingAxis>{
      ArticulatingAxis.inclusion,
      ArticulatingAxis.criticalThinking,
    },
    targetGrades: <PrimaryGrade>{PrimaryGrade.second, PrimaryGrade.third},
  );

  test('project exposes the three reference lifecycle states', () {
    expect(ProjectLifecycle.values, <ProjectLifecycle>[
      ProjectLifecycle.draft,
      ProjectLifecycle.inProgress,
      ProjectLifecycle.completed,
    ]);
  });

  test('project carries methodology, articulating axes and grade scope', () {
    expect(project.methodology, ProjectMethodology.communityProjects);
    expect(project.articulatingAxes, contains(ArticulatingAxis.inclusion));
    expect(project.targetGrades, <PrimaryGrade>{
      PrimaryGrade.second,
      PrimaryGrade.third,
    });
  });

  test(
    'project normalizes optional planning text and validates date range',
    () {
      final detailed = Project(
        id: 'project-details',
        groupId: 'group-1',
        title: 'Agua',
        description: '  Investigar el consumo de agua.  ',
        startsOn: DateTime(2026, 9, 1),
        endsOn: DateTime(2026, 9, 30),
        observations: '   ',
        lifecycle: ProjectLifecycle.inProgress,
        methodology: ProjectMethodology.inquirySteam,
        targetGrades: <PrimaryGrade>{PrimaryGrade.third},
      );

      expect(detailed.description, 'Investigar el consumo de agua.');
      expect(detailed.observations, isNull);
      expect(detailed.startsOn, DateTime(2026, 9, 1));
      expect(detailed.endsOn, DateTime(2026, 9, 30));

      expect(
        () => Project(
          id: 'project-invalid-range',
          groupId: 'group-1',
          title: 'Fechas inválidas',
          startsOn: DateTime(2026, 10, 1),
          endsOn: DateTime(2026, 9, 30),
          lifecycle: ProjectLifecycle.draft,
          methodology: ProjectMethodology.unspecified,
          targetGrades: <PrimaryGrade>{PrimaryGrade.third},
        ),
        throwsArgumentError,
      );
    },
  );

  test('project must target at least one grade', () {
    expect(
      () => Project(
        id: 'project-2',
        groupId: 'group-1',
        title: 'Vacío',
        lifecycle: ProjectLifecycle.draft,
        methodology: ProjectMethodology.unspecified,
        targetGrades: <PrimaryGrade>{},
      ),
      throwsArgumentError,
    );
  });

  test(
    'activity field is independent while grades stay inside project scope',
    () {
      final valid = Activity(
        id: 'activity-1',
        projectId: project.id,
        title: 'Investigar',
        formativeField: FormativeField.knowledgeAndScientificThought,
        targetGrades: <PrimaryGrade>{PrimaryGrade.second},
        roster: <ActivityParticipant>[
          ActivityParticipant(
            studentId: 'student-1',
            grade: PrimaryGrade.second,
          ),
        ],
      );
      final invalidGrade = Activity(
        id: 'activity-2',
        projectId: project.id,
        title: 'Fuera de alcance',
        formativeField: FormativeField.languages,
        targetGrades: <PrimaryGrade>{PrimaryGrade.fourth},
        roster: const <ActivityParticipant>[],
      );

      expect(
        ActivityPolicy.validate(activity: valid, project: project),
        isEmpty,
      );
      expect(
        ActivityPolicy.validate(activity: invalidGrade, project: project),
        contains(ActivityViolation.targetGradeOutsideProject),
      );
    },
  );

  test('activity keeps identifier and normalized calendar date', () {
    final activity = Activity(
      id: 'activity-1',
      projectId: project.id,
      identifier: 'A3',
      title: 'Ceremonia escolar',
      occursOn: DateTime(2026, 9, 16, 14, 30),
      formativeField: FormativeField.humanAndCommunity,
      targetGrades: <PrimaryGrade>{PrimaryGrade.second},
      roster: const <ActivityParticipant>[],
    );

    expect(activity.displayIdentifier, 'A3');
    expect(activity.occursOn, DateTime(2026, 9, 16, 14, 30));
  });

  test('activity normalizes optional description and observations', () {
    final activity = Activity(
      id: 'activity-details',
      projectId: project.id,
      title: 'Entrevista',
      description: '  Preparar cinco preguntas abiertas. ',
      generalObservations: '   ',
      formativeField: FormativeField.languages,
      targetGrades: <PrimaryGrade>{PrimaryGrade.second},
      roster: const <ActivityParticipant>[],
    );

    expect(activity.description, 'Preparar cinco preguntas abiertas.');
    expect(activity.generalObservations, isNull);
  });

  test('activity freezes student id and grade in its historical roster', () {
    final activity = Activity(
      id: 'activity-1',
      projectId: project.id,
      title: 'Producto',
      formativeField: FormativeField.humanAndCommunity,
      targetGrades: <PrimaryGrade>{PrimaryGrade.second, PrimaryGrade.third},
      roster: <ActivityParticipant>[
        ActivityParticipant(studentId: 'student-1', grade: PrimaryGrade.second),
        ActivityParticipant(studentId: 'student-2', grade: PrimaryGrade.third),
      ],
    );

    expect(activity.isApplicableTo('student-1'), isTrue);
    expect(activity.isApplicableTo('student-3'), isFalse);
    expect(activity.roster['student-2']?.grade, PrimaryGrade.third);
  });

  test('participant grade must be inside the activity target grades', () {
    expect(
      () => Activity(
        id: 'activity-1',
        projectId: project.id,
        title: 'Producto',
        formativeField: FormativeField.humanAndCommunity,
        targetGrades: <PrimaryGrade>{PrimaryGrade.second},
        roster: <ActivityParticipant>[
          ActivityParticipant(
            studentId: 'student-1',
            grade: PrimaryGrade.third,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
