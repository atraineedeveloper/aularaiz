import 'package:aularaiz/domain/student/enrollment.dart';

abstract interface class EnrollmentRepository {
  Future<List<Enrollment>> findByStudentId(String studentId);

  Future<List<Enrollment>> findByGroupId(String groupId);

  Future<void> save(Enrollment enrollment);
}
