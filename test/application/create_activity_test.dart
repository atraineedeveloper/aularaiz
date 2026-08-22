import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/project/create_activity.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activity snapshots active students inside selected grade scope', () async {
    final project = Project(
      id: 'project-1',
      groupId: 'group-1',
      title: 'Comunidad y agua',
      lifecycle: ProjectLifecycle.inProgress,
      methodology: ProjectMethodology.communityProjects,
      formativeField: FormativeField.ethicsNatureAndSocieties,
      targetGrades: {PrimaryGrade.first, PrimaryGrade.second},
    );
    final activityRepository = _MemoryActivityRepository();
    final useCase = CreateActivity(
      activityRepository: activityRepository,
      projectRepository: _MemoryProjectRepository(project),
      enrollmentRepository: _MemoryEnrollmentRepository([
        _enrollment('first-active', PrimaryGrade.first),
        _enrollment('second-active', PrimaryGrade.second),
        _enrollment('third-active', PrimaryGrade.third),
        _enrollment(
          'first-ended',
          PrimaryGrade.first,
          endsOn: DateTime(2026, 8, 10),
        ),
      ]),
      idGenerator: _FixedIdGenerator(),
    );

    final activity = await useCase(
      projectId: project.id,
      title: 'Mapa de fuentes de agua',
      targetGrades: {PrimaryGrade.first},
      rosterDate: DateTime(2026, 8, 22),
    );

    expect(activity.roster.keys, <String>{'first-active'});
    expect(activity.roster['first-active']?.grade, PrimaryGrade.first);
    expect(activityRepository.saved?.roster.keys, <String>{'first-active'});
  });

  test('activity rejects grades outside project scope', () async {
    final project = Project(
      id: 'project-1',
      groupId: 'group-1',
      title: 'Proyecto',
      lifecycle: ProjectLifecycle.draft,
      methodology: ProjectMethodology.unspecified,
      formativeField: FormativeField.unspecified,
      targetGrades: {PrimaryGrade.first},
    );
    final useCase = CreateActivity(
      activityRepository: _MemoryActivityRepository(),
      projectRepository: _MemoryProjectRepository(project),
      enrollmentRepository: _MemoryEnrollmentRepository(const []),
      idGenerator: _FixedIdGenerator(),
    );

    expect(
      () => useCase(
        projectId: project.id,
        title: 'Fuera de alcance',
        targetGrades: {PrimaryGrade.second},
        rosterDate: DateTime(2026, 8, 22),
      ),
      throwsArgumentError,
    );
  });
}

Enrollment _enrollment(
  String studentId,
  PrimaryGrade grade, {
  DateTime? endsOn,
}) {
  return Enrollment(
    id: 'enrollment-$studentId',
    studentId: studentId,
    groupId: 'group-1',
    grade: grade,
    listNumber: studentId.hashCode.abs() + 1,
    startsOn: DateTime(2026, 8, 1),
    endsOn: endsOn,
  );
}

final class _FixedIdGenerator implements IdGenerator {
  @override
  String newId() => 'activity-1';
}

final class _MemoryProjectRepository implements ProjectRepository {
  _MemoryProjectRepository(this.project);

  final Project project;

  @override
  Future<Project?> findById(String id) async => id == project.id ? project : null;

  @override
  Future<List<Project>> listForGroup(String groupId) async => [project];

  @override
  Future<void> save(Project project) async {}
}

final class _MemoryEnrollmentRepository implements EnrollmentRepository {
  _MemoryEnrollmentRepository(this.values);

  final List<Enrollment> values;

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async => values;

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async {
    return values
        .where((enrollment) => enrollment.studentId == studentId)
        .toList();
  }

  @override
  Future<void> save(Enrollment enrollment) async {}
}

final class _MemoryActivityRepository implements ActivityRepository {
  Activity? saved;

  @override
  Future<Activity?> findById(String id) async => saved?.id == id ? saved : null;

  @override
  Future<List<Activity>> listForProject(String projectId) async {
    return saved == null ? const [] : [saved!];
  }

  @override
  Future<void> save(Activity activity) async {
    saved = activity;
  }
}
