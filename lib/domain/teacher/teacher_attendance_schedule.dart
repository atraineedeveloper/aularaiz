final class TeacherAttendanceSchedule {
  TeacherAttendanceSchedule({
    required this.schoolId,
    required this.expectedArrivalMinute,
    required this.expectedDepartureMinute,
    this.arrivalGraceMinutes = 10,
  }) {
    if (schoolId.trim().isEmpty) {
      throw ArgumentError.value(schoolId, 'schoolId', 'School is required.');
    }
    if ((expectedArrivalMinute == null) != (expectedDepartureMinute == null)) {
      throw ArgumentError('Set both schedule times or leave both unset.');
    }
    for (final minute in [expectedArrivalMinute, expectedDepartureMinute]) {
      if (minute != null && (minute < 0 || minute >= 24 * 60)) {
        throw ArgumentError.value(minute, 'minute', 'Invalid time of day.');
      }
    }
    if (expectedArrivalMinute != null &&
        expectedDepartureMinute! <= expectedArrivalMinute!) {
      throw ArgumentError('Departure must be later than arrival.');
    }
    if (arrivalGraceMinutes < 0 || arrivalGraceMinutes > 240) {
      throw ArgumentError.value(
        arrivalGraceMinutes,
        'arrivalGraceMinutes',
        'Grace period must be between 0 and 240 minutes.',
      );
    }
  }

  final String schoolId;
  final int? expectedArrivalMinute;
  final int? expectedDepartureMinute;
  final int arrivalGraceMinutes;

  bool get isConfigured => expectedArrivalMinute != null;

  bool isLate(DateTime arrival) =>
      expectedArrivalMinute != null &&
      (arrival.hour * 60 + arrival.minute) >
          expectedArrivalMinute! + arrivalGraceMinutes;

  bool leftEarly(DateTime departure) =>
      expectedDepartureMinute != null &&
      departure.hour * 60 + departure.minute < expectedDepartureMinute!;
}
