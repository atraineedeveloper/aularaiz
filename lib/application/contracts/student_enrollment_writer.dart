import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';

abstract interface class StudentEnrollmentWriter {
  Future<void> saveNewStudentWithEnrollment({
    required Student student,
    required Enrollment enrollment,
  });
}
