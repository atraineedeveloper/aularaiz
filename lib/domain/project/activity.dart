import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';

final class Activity {
  Activity({
    required this.id,
    required this.projectId,
    required this.title,
    required Set<PrimaryGrade> targetGrades,
    required Iterable<ActivityParticipant> roster,
  }) : targetGrades = Set<PrimaryGrade>.unmodifiable(targetGrades),
       roster = _buildRoster(roster, targetGrades) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Activity id cannot be empty.');
    }
    if (projectId.trim().isEmpty) {
      throw ArgumentError.value(
        projectId,
        'projectId',
        'Activity project id cannot be empty.',
      );
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Activity title cannot be empty.',
      );
    }
    if (targetGrades.isEmpty) {
      throw ArgumentError.value(
        targetGrades,
        'targetGrades',
        'Activity must target at least one grade.',
      );
    }
  }

  final String id;
  final String projectId;
  final String title;
  final Set<PrimaryGrade> targetGrades;
  final Map<String, ActivityParticipant> roster;

  bool isApplicableTo(String studentId) => roster.containsKey(studentId);

  static Map<String, ActivityParticipant> _buildRoster(
    Iterable<ActivityParticipant> source,
    Set<PrimaryGrade> targetGrades,
  ) {
    final result = <String, ActivityParticipant>{};
    for (final participant in source) {
      if (!targetGrades.contains(participant.grade)) {
        throw ArgumentError.value(
          participant.grade,
          'roster',
          'Participant grade must be inside the activity target grades.',
        );
      }
      if (result.containsKey(participant.studentId)) {
        throw ArgumentError.value(
          participant.studentId,
          'roster',
          'Activity roster cannot contain duplicate students.',
        );
      }
      result[participant.studentId] = participant;
    }
    return Map<String, ActivityParticipant>.unmodifiable(result);
  }
}
