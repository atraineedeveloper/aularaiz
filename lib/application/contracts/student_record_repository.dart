import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';

abstract interface class StudentRecordRepository {
  Future<StudentRecord?> find(String studentId);

  Future<void> save(StudentRecord record);

  Future<List<StudentRecordEntry>> listEntries(String studentId);

  Future<void> addEntry(StudentRecordEntry entry);
}
