import 'package:aularaiz/domain/student/student.dart';

abstract interface class StudentRepository {
  Future<Student?> findById(String id);

  Future<List<Student>> listAll();

  Future<void> save(Student student);
}
