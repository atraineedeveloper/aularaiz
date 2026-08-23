import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';

final class AddStudentRecordEntry {
  AddStudentRecordEntry({
    required StudentRepository studentRepository,
    required StudentRecordRepository studentRecordRepository,
    required IdGenerator idGenerator,
  }) : _studentRepository = studentRepository,
       _studentRecordRepository = studentRecordRepository,
       _idGenerator = idGenerator;

  final StudentRepository _studentRepository;
  final StudentRecordRepository _studentRecordRepository;
  final IdGenerator _idGenerator;

  Future<StudentRecordEntry> call({
    required String studentId,
    required StudentRecordEntryKind kind,
    required DateTime occurredAt,
    required String text,
  }) async {
    final student = await _studentRepository.findById(studentId);
    if (student == null) {
      throw StateError('Student does not exist.');
    }

    final entry = StudentRecordEntry(
      id: _idGenerator.newId(),
      studentId: studentId,
      kind: kind,
      occurredAt: occurredAt,
      text: text,
    );
    await _studentRecordRepository.addEntry(entry);
    return entry;
  }
}
