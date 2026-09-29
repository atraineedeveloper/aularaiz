final class TeacherAttendanceRecord {
  TeacherAttendanceRecord({
    required this.id,
    required this.schoolId,
    required DateTime attendanceDate,
    required this.arrivedAt,
    this.departedAt,
    this.notes,
    this.correctedAt,
    this.expectedArrivalMinute,
    this.expectedDepartureMinute,
    this.arrivalGraceMinutes,
  }) : attendanceDate = DateTime(
         attendanceDate.year,
         attendanceDate.month,
         attendanceDate.day,
       ) {
    if (id.trim().isEmpty || schoolId.trim().isEmpty) {
      throw ArgumentError('Record and school identifiers are required.');
    }
    if (departedAt != null && departedAt!.isBefore(arrivedAt)) {
      throw ArgumentError.value(
        departedAt,
        'departedAt',
        'Departure cannot be earlier than arrival.',
      );
    }
  }

  final String id;
  final String schoolId;
  final DateTime attendanceDate;
  final DateTime arrivedAt;
  final DateTime? departedAt;
  final String? notes;
  final DateTime? correctedAt;
  final int? expectedArrivalMinute;
  final int? expectedDepartureMinute;
  final int? arrivalGraceMinutes;

  bool get isOpen => departedAt == null;
  bool get wasCorrected => correctedAt != null;

  TeacherAttendanceRecord copyWith({
    DateTime? arrivedAt,
    DateTime? departedAt,
    bool clearDeparture = false,
    String? notes,
    bool clearNotes = false,
    DateTime? correctedAt,
  }) => TeacherAttendanceRecord(
    id: id,
    schoolId: schoolId,
    attendanceDate: attendanceDate,
    arrivedAt: arrivedAt ?? this.arrivedAt,
    departedAt: clearDeparture ? null : departedAt ?? this.departedAt,
    notes: clearNotes ? null : notes ?? this.notes,
    correctedAt: correctedAt ?? this.correctedAt,
    expectedArrivalMinute: expectedArrivalMinute,
    expectedDepartureMinute: expectedDepartureMinute,
    arrivalGraceMinutes: arrivalGraceMinutes,
  );
}
