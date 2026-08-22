import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';

final class StudentRecordEntry {
  StudentRecordEntry({
    required this.id,
    required this.studentId,
    required this.kind,
    required DateTime occurredAt,
    required String text,
  }) : occurredAt = occurredAt.toUtc(),
       text = text.trim() {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Record entry id cannot be empty.');
    }
    if (studentId.trim().isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Record entry student id cannot be empty.',
      );
    }
    if (text.trim().isEmpty) {
      throw ArgumentError.value(
        text,
        'text',
        'Record entry text cannot be empty.',
      );
    }
  }

  final String id;
  final String studentId;
  final StudentRecordEntryKind kind;
  final DateTime occurredAt;
  final String text;
}
