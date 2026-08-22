import 'package:aularaiz/domain/education/primary_grade.dart';

final class Enrollment {
  Enrollment({
    required this.id,
    required this.studentId,
    required this.groupId,
    required this.grade,
    required this.startsOn,
    this.endsOn,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Enrollment id cannot be empty.');
    }
    if (studentId.trim().isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Student id cannot be empty.',
      );
    }
    if (groupId.trim().isEmpty) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Group id cannot be empty.',
      );
    }
    if (endsOn != null && endsOn!.isBefore(startsOn)) {
      throw ArgumentError('Enrollment end date cannot precede its start date.');
    }
  }

  final String id;
  final String studentId;
  final String groupId;
  final PrimaryGrade grade;
  final DateTime startsOn;
  final DateTime? endsOn;

  bool isActiveOn(DateTime date) {
    if (date.isBefore(startsOn)) return false;
    final end = endsOn;
    return end == null || !date.isAfter(end);
  }

  bool overlaps(Enrollment other) {
    final end = endsOn;
    if (end != null && end.isBefore(other.startsOn)) return false;

    final otherEnd = other.endsOn;
    if (otherEnd != null && otherEnd.isBefore(startsOn)) return false;

    return true;
  }
}
