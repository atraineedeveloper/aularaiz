import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';

final class SaveStudentRecord {
  SaveStudentRecord({
    required StudentRepository studentRepository,
    required StudentRecordRepository recordRepository,
  }) : _studentRepository = studentRepository,
       _recordRepository = recordRepository;

  final StudentRepository _studentRepository;
  final StudentRecordRepository _recordRepository;

  Future<void> call(StudentRecord record) async {
    final student = await _studentRepository.findById(record.studentId);
    if (student == null) {
      throw StateError('Student does not exist.');
    }
    await _recordRepository.save(record);
  }
}
