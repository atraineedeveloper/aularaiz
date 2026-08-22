final class StudentRecord {
  StudentRecord({
    required this.studentId,
    String? strengths,
    String? difficulties,
    String? supports,
  }) : strengths = _normalizeOptionalText(strengths),
       difficulties = _normalizeOptionalText(difficulties),
       supports = _normalizeOptionalText(supports) {
    if (studentId.trim().isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Student record id cannot be empty.',
      );
    }
  }

  final String studentId;
  final String? strengths;
  final String? difficulties;
  final String? supports;

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
