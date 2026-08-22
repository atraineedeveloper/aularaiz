import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('student record normalizes optional pedagogical fields', () {
    final record = StudentRecord(
      studentId: 'student-1',
      strengths: '  Participa con iniciativa  ',
      difficulties: '   ',
      supports: '  Lectura acompañada  ',
    );

    expect(record.strengths, 'Participa con iniciativa');
    expect(record.difficulties, isNull);
    expect(record.supports, 'Lectura acompañada');
  });

  test('record entries keep chronological evidence in UTC', () {
    final entry = StudentRecordEntry(
      id: 'entry-1',
      studentId: 'student-1',
      kind: StudentRecordEntryKind.observation,
      occurredAt: DateTime.parse('2026-09-01T10:00:00-06:00'),
      text: '  Participó en la lectura grupal.  ',
    );

    expect(entry.occurredAt, DateTime.utc(2026, 9, 1, 16));
    expect(entry.text, 'Participó en la lectura grupal.');
  });

  test('family agreements remain distinct from pedagogical observations', () {
    expect(StudentRecordEntryKind.values, <StudentRecordEntryKind>[
      StudentRecordEntryKind.observation,
      StudentRecordEntryKind.familyAgreement,
    ]);
  });

  test('empty chronological entries are rejected', () {
    expect(
      () => StudentRecordEntry(
        id: 'entry-1',
        studentId: 'student-1',
        kind: StudentRecordEntryKind.familyAgreement,
        occurredAt: DateTime.utc(2026, 9),
        text: '   ',
      ),
      throwsArgumentError,
    );
  });
}
