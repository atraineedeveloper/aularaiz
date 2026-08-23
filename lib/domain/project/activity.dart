import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/formative_field.dart';

final class Activity {
  Activity({
    required this.id,
    required this.projectId,
    required this.title,
    required this.formativeField,
    this.identifier,
    this.occursOn,
    required Set<PrimaryGrade> targetGrades,
    required Iterable<ActivityParticipant> roster,
  }) : targetGrades = Set<PrimaryGrade>.unmodifiable(targetGrades),
       roster = _buildRoster(roster, targetGrades) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Activity id cannot be empty.');
    }
    if (projectId.trim().isEmpty) {
      throw ArgumentError.value(projectId, 'projectId', 'Activity project id cannot be empty.');
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', 'Activity title cannot be empty.');
    }
    if (identifier != null && identifier!.trim().isEmpty) {
      throw ArgumentError.value(identifier, 'identifier', 'Activity identifier cannot be blank.');
    }
    if (targetGrades.isEmpty) {
      throw ArgumentError.value(targetGrades, 'targetGrades', 'Activity must target at least one grade.');
    }
  }

  final String id;
  final String projectId;
  final String title;
  final FormativeField formativeField;
  final String? identifier;
  final DateTime? occursOn;
  final Set<PrimaryGrade> targetGrades;
  final Map<String, ActivityParticipant> roster;

  String get displayIdentifier {
    final value = identifier?.trim();
    if (value != null && value.isNotEmpty) return value;
    final short = id.length <= 4 ? id : id.substring(0, 4);
    return 'A-${short.toUpperCase()}';
  }

  bool isApplicableTo(String studentId) => roster.containsKey(studentId);

  static Map<String, ActivityParticipant> _buildRoster(
    Iterable<ActivityParticipant> source,
    Set<PrimaryGrade> targetGrades,
  ) {
    final result = <String, ActivityParticipant>{};
    for (final participant in source) {
      if (!targetGrades.contains(participant.grade)) {
        throw ArgumentError.value(participant.grade, 'roster', 'Participant grade must be inside the activity target grades.');
      }
      if (result.containsKey(participant.studentId)) {
        throw ArgumentError.value(participant.studentId, 'roster', 'Activity roster cannot contain duplicate students.');
      }
      result[participant.studentId] = participant;
    }
    return Map<String, ActivityParticipant>.unmodifiable(result);
  }
}
