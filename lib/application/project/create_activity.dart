import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';

final class CreateActivity {
  CreateActivity({
    required ActivityRepository activityRepository,
    required ProjectRepository projectRepository,
    required EnrollmentRepository enrollmentRepository,
    required IdGenerator idGenerator,
  }) : _activityRepository = activityRepository,
       _projectRepository = projectRepository,
       _enrollmentRepository = enrollmentRepository,
       _idGenerator = idGenerator;

  final ActivityRepository _activityRepository;
  final ProjectRepository _projectRepository;
  final EnrollmentRepository _enrollmentRepository;
  final IdGenerator _idGenerator;

  Future<Activity> call({
    required String projectId,
    required String title,
    required Set<PrimaryGrade> targetGrades,
    required DateTime rosterDate,
  }) async {
    final project = await _projectRepository.findById(projectId);
    if (project == null) throw StateError('Project does not exist.');
    if (!project.allowsActivityGrades(targetGrades)) {
      throw ArgumentError('Activity grades must be inside the project scope.');
    }

    final enrollments = await _enrollmentRepository.findByGroupId(
      project.groupId,
    );
    final roster = <ActivityParticipant>[];
    for (final enrollment in enrollments) {
      if (enrollment.isActiveOn(rosterDate) &&
          targetGrades.contains(enrollment.grade)) {
        roster.add(
          ActivityParticipant(
            studentId: enrollment.studentId,
            grade: enrollment.grade,
          ),
        );
      }
    }

    final activity = Activity(
      id: _idGenerator.newId(),
      projectId: projectId,
      title: title,
      targetGrades: targetGrades,
      roster: roster,
    );
    await _activityRepository.save(activity);
    return activity;
  }
}
