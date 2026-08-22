import 'package:aularaiz/domain/student/enrollment.dart';

abstract interface class EnrollmentRepository {
  Future<List<Enrollment>> findByStudentId(String studentId);

  Future<void> save(Enrollment enrollment);
}
