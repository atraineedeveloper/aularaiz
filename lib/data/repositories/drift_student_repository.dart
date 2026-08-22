import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:drift/drift.dart';

final class DriftStudentRepository implements StudentRepository {
  DriftStudentRepository(this.database);

  final AppDatabase database;

  @override
  Future<Student?> findById(String id) async {
    final row = await (database.select(
      database.students,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Student>> listAll() async {
    final rows = await database.select(database.students).get();
    final students = rows.map(_toDomain).toList(growable: false);
    students.sort((left, right) => left.displayName.compareTo(right.displayName));
    return students;
  }

  @override
  Future<void> save(Student student) async {
    await database.into(database.students).insertOnConflictUpdate(
      StudentsCompanion(
        id: Value(student.id),
        givenNames: Value(student.givenNames),
        firstSurname: Value(student.firstSurname),
        secondSurname: Value(student.secondSurname),
        birthDate: Value(student.birthDate),
      ),
    );
  }

  Student _toDomain(StudentRow row) {
    return Student(
      id: row.id,
      givenNames: row.givenNames,
      firstSurname: row.firstSurname,
      secondSurname: row.secondSurname,
      birthDate: row.birthDate,
    );
  }
}
