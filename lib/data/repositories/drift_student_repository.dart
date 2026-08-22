import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/student/student.dart';

final class DriftStudentRepository implements StudentRepository {
  DriftStudentRepository(this.database);

  final AppDatabase database;

  @override
  Future<Student?> findById(String id) async {
    final row = await (database.select(
      database.students,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    if (row == null) return null;

    return Student(
      id: row.id,
      givenNames: row.givenNames,
      firstSurname: row.firstSurname,
      secondSurname: row.secondSurname,
      birthDate: row.birthDate,
    );
  }
}
