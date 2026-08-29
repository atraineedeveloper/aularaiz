final class TeachingContract {
  TeachingContract({required this.startsOn, required this.endsOn}) {
    if (endsOn.isBefore(startsOn)) {
      throw ArgumentError(
        'Teaching contract end date cannot precede its start date.',
      );
    }
  }

  final DateTime startsOn;
  final DateTime endsOn;

  bool contains(DateTime date) {
    return !date.isBefore(startsOn) && !date.isAfter(endsOn);
  }
}
