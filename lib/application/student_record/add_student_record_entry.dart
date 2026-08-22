import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';

final class AddStudentRecordEntry {
  AddStudentRecordEntry({
    required StudentRepository studentRepository,
    required StudentRecordRepository recordRepository,
    required IdGenerator idGenerator,
  }) : _studentRepository = studentRepository,
       _recordRepository = recordRepository,
       _idGenerator = idGenerator;

  final StudentRepository _studentRepository;
  final StudentRecordRepository _recordRepository;
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
    await _recordRepository.addEntry(entry);
    return entry;
  }
}
