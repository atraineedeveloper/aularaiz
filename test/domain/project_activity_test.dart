import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/activity_policy.dart';
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
    formativeField: FormativeField.humanAndCommunity,
    targetGrades: <PrimaryGrade>{PrimaryGrade.second, PrimaryGrade.third},
  );

  test('project exposes the three reference lifecycle states', () {
    expect(ProjectLifecycle.values, <ProjectLifecycle>[
      ProjectLifecycle.draft,
      ProjectLifecycle.inProgress,
      ProjectLifecycle.completed,
    ]);
  });

  test('project must target at least one grade', () {
    expect(
      () => Project(
        id: 'project-2',
        groupId: 'group-1',
        title: 'Vacío',
        lifecycle: ProjectLifecycle.draft,
        methodology: ProjectMethodology.unspecified,
        formativeField: FormativeField.unspecified,
        targetGrades: <PrimaryGrade>{},
      ),
      throwsArgumentError,
    );
  });

  test('activity grades must be a subset of project target grades', () {
    final valid = Activity(
      id: 'activity-1',
      projectId: project.id,
      title: 'Investigar',
      targetGrades: <PrimaryGrade>{PrimaryGrade.second},
      roster: <ActivityParticipant>[
        ActivityParticipant(
          studentId: 'student-1',
          grade: PrimaryGrade.second,
        ),
      ],
    );
    final invalid = Activity(
      id: 'activity-2',
      projectId: project.id,
      title: 'Fuera de alcance',
      targetGrades: <PrimaryGrade>{PrimaryGrade.fourth},
      roster: const <ActivityParticipant>[],
    );

    expect(
      ActivityPolicy.validate(activity: valid, project: project),
      isEmpty,
    );
    expect(
      ActivityPolicy.validate(activity: invalid, project: project),
      contains(ActivityViolation.targetGradeOutsideProject),
    );
  });

  test('activity freezes student id and grade in its historical roster', () {
    final activity = Activity(
      id: 'activity-1',
      projectId: project.id,
      title: 'Producto',
      targetGrades: <PrimaryGrade>{PrimaryGrade.second, PrimaryGrade.third},
      roster: <ActivityParticipant>[
        ActivityParticipant(
          studentId: 'student-1',
          grade: PrimaryGrade.second,
        ),
        ActivityParticipant(
          studentId: 'student-2',
          grade: PrimaryGrade.third,
        ),
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
