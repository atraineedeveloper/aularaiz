import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/student/enrollment.dart';

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
    required FormativeField formativeField,
    required Set<PrimaryGrade> targetGrades,
    required DateTime rosterDate,
  }) async {
    final project = await _projectRepository.findById(projectId);
    if (project == null) throw StateError('Project does not exist.');
    if (!project.allowsActivityGrades(targetGrades)) {
      throw ArgumentError('Activity grades must be inside the project scope.');
    }
    if (!project.allowsActivityField(formativeField)) {
      throw ArgumentError(
        'Activity formative field must be included in the project.',
      );
    }

    final enrollments = await _enrollmentRepository.findByGroupId(
      project.groupId,
    );
    final eligible = enrollments
        .where((enrollment) => targetGrades.contains(enrollment.grade))
        .toList();
    final effectiveRosterDate = _effectiveRosterDate(eligible, rosterDate);
    final roster = <ActivityParticipant>[
      for (final enrollment in eligible)
        if (enrollment.isActiveOn(effectiveRosterDate))
          ActivityParticipant(
            studentId: enrollment.studentId,
            grade: enrollment.grade,
          ),
    ];

    final activity = Activity(
      id: _idGenerator.newId(),
      projectId: projectId,
      title: title,
      formativeField: formativeField,
      targetGrades: targetGrades,
      roster: roster,
    );
    await _activityRepository.save(activity);
    return activity;
  }

  DateTime _effectiveRosterDate(
    List<Enrollment> eligible,
    DateTime requested,
  ) {
    final normalized = DateTime(requested.year, requested.month, requested.day);
    if (eligible.any((enrollment) => enrollment.isActiveOn(normalized))) {
      return normalized;
    }

    final upcoming = eligible
        .map((enrollment) => enrollment.startsOn)
        .where((date) => date.isAfter(normalized))
        .toList()
      ..sort();
    return upcoming.isEmpty ? normalized : upcoming.first;
  }
}
