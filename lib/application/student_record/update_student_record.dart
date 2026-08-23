import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';

final class UpdateStudentRecord {
  UpdateStudentRecord({
    required StudentRepository studentRepository,
    required StudentRecordRepository studentRecordRepository,
  }) : _studentRepository = studentRepository,
       _studentRecordRepository = studentRecordRepository;

  final StudentRepository _studentRepository;
  final StudentRecordRepository _studentRecordRepository;

  Future<StudentRecord> call({
    required String studentId,
    String? strengths,
    String? difficulties,
    String? supports,
  }) async {
    final student = await _studentRepository.findById(studentId);
    if (student == null) {
      throw StateError('Student does not exist.');
    }

    final record = StudentRecord(
      studentId: studentId,
      strengths: strengths,
      difficulties: difficulties,
      supports: supports,
    );
    await _studentRecordRepository.save(record);
    return record;
  }
}
