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
    formativeFields: <FormativeField>{
      FormativeField.humanAndCommunity,
      FormativeField.languages,
    },
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

  test('project supports multiple formative fields and articulating axes', () {
    expect(project.formativeFields, hasLength(2));
    expect(project.formativeFields, contains(FormativeField.languages));
    expect(project.articulatingAxes, contains(ArticulatingAxis.inclusion));
  });

  test('project must target at least one grade', () {
    expect(
      () => Project(
        id: 'project-2',
        groupId: 'group-1',
        title: 'Vacío',
        lifecycle: ProjectLifecycle.draft,
        methodology: ProjectMethodology.unspecified,
        formativeFields: <FormativeField>{FormativeField.languages},
        targetGrades: <PrimaryGrade>{},
      ),
      throwsArgumentError,
    );
  });

  test('project must include at least one formative field', () {
    expect(
      () => Project(
        id: 'project-2',
        groupId: 'group-1',
        title: 'Vacío',
        lifecycle: ProjectLifecycle.draft,
        methodology: ProjectMethodology.unspecified,
        formativeFields: <FormativeField>{},
        targetGrades: <PrimaryGrade>{PrimaryGrade.second},
      ),
      throwsArgumentError,
    );
  });

  test('activity grades and field must stay inside project scope', () {
    final valid = Activity(
      id: 'activity-1',
      projectId: project.id,
      title: 'Investigar',
      formativeField: FormativeField.languages,
      targetGrades: <PrimaryGrade>{PrimaryGrade.second},
      roster: <ActivityParticipant>[
        ActivityParticipant(studentId: 'student-1', grade: PrimaryGrade.second),
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
    final invalidField = Activity(
      id: 'activity-3',
      projectId: project.id,
      title: 'Campo fuera de alcance',
      formativeField: FormativeField.knowledgeAndScientificThought,
      targetGrades: <PrimaryGrade>{PrimaryGrade.second},
      roster: const <ActivityParticipant>[],
    );

    expect(ActivityPolicy.validate(activity: valid, project: project), isEmpty);
    expect(
      ActivityPolicy.validate(activity: invalidGrade, project: project),
      contains(ActivityViolation.targetGradeOutsideProject),
    );
    expect(
      ActivityPolicy.validate(activity: invalidField, project: project),
      contains(ActivityViolation.formativeFieldOutsideProject),
    );
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
