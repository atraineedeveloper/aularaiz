import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';

final class NewStudentEnrollment {
  const NewStudentEnrollment({
    required this.student,
    required this.enrollment,
  });

  final Student student;
  final Enrollment enrollment;
}

abstract interface class StudentEnrollmentBatchWriter {
  Future<void> saveBatch(List<NewStudentEnrollment> entries);
}
