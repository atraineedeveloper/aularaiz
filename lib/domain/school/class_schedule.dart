final class ClassSchedule {
  ClassSchedule({required this.startsAtMinutes, required this.endsAtMinutes}) {
    _validateMinuteOfDay(startsAtMinutes, 'startsAtMinutes');
    _validateMinuteOfDay(endsAtMinutes, 'endsAtMinutes');
    if (endsAtMinutes <= startsAtMinutes) {
      throw ArgumentError('Class schedule must end after it starts.');
    }
  }

  final int startsAtMinutes;
  final int endsAtMinutes;

  static void _validateMinuteOfDay(int value, String name) {
    if (value < 0 || value >= 24 * 60) {
      throw ArgumentError.value(
        value,
        name,
        'Schedule minutes must be inside a calendar day.',
      );
    }
  }
}
