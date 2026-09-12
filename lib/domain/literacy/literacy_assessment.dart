import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';

final class LiteracyAssessment {
  LiteracyAssessment({
    required this.id,
    required this.studentId,
    required DateTime assessedAt,
    required this.writingLevel,
    required this.readingLevel,
    String? notes,
  }) : assessedAt = assessedAt.toUtc(),
       notes = _normalizeOptional(notes) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Assessment id cannot be empty.');
    }
    if (studentId.trim().isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Assessment student id cannot be empty.',
      );
    }
  }

  final String id;
  final String studentId;
  final DateTime assessedAt;
  final WritingLevel writingLevel;
  final ReadingLevel readingLevel;
  final String? notes;

  LiteracyAssessment copyWith({
    DateTime? assessedAt,
    WritingLevel? writingLevel,
    ReadingLevel? readingLevel,
    String? notes,
  }) {
    return LiteracyAssessment(
      id: id,
      studentId: studentId,
      assessedAt: assessedAt ?? this.assessedAt,
      writingLevel: writingLevel ?? this.writingLevel,
      readingLevel: readingLevel ?? this.readingLevel,
      notes: notes ?? this.notes,
    );
  }

  static String? _normalizeOptional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
