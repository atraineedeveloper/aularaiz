final class SchoolYear {
  SchoolYear({
    required this.id,
    required this.label,
    required this.startsOn,
    required this.endsOn,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'School year id cannot be empty.');
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(
        label,
        'label',
        'School year label cannot be empty.',
      );
    }
    if (endsOn.isBefore(startsOn)) {
      throw ArgumentError('School year end date cannot precede its start date.');
    }
  }

  final String id;
  final String label;
  final DateTime startsOn;
  final DateTime endsOn;

  bool contains(DateTime date) {
    return !date.isBefore(startsOn) && !date.isAfter(endsOn);
  }
}
