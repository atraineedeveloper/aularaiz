final class Enrollment {
  Enrollment({
    required this.id,
    required this.studentId,
    required this.groupId,
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
  final DateTime startsOn;
  final DateTime? endsOn;

  bool isActiveOn(DateTime date) {
    if (date.isBefore(startsOn)) return false;
    final end = endsOn;
    return end == null || !date.isAfter(end);
  }
}
