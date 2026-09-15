import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:drift/drift.dart';

final class DriftStudentRepository implements StudentRepository {
  DriftStudentRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<Student?> findById(String id) async {
    final row =
        await (database.select(
              database.students,
            )..where((table) => table.id.equals(id) & table.deletedAt.isNull()))
            .getSingleOrNull();

    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Student>> listAll() async {
    final rows = await (database.select(
      database.students,
    )..where((table) => table.deletedAt.isNull())).get();
    final students = rows.map(_toDomain).toList(growable: false);
    students.sort(
      (left, right) => left.displayName.compareTo(right.displayName),
    );
    return students;
  }

  @override
  Future<void> save(Student student) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database
        .into(database.students)
        .insertOnConflictUpdate(
          StudentsCompanion(
            id: Value(student.id),
            givenNames: Value(student.givenNames),
            firstSurname: Value(student.firstSurname),
            secondSurname: Value(student.secondSurname),
            sex: Value(student.sex),
            birthDate: Value(student.birthDate),
            deletedAt: const Value(null),
            updatedAt: SyncMetadataValues.updated(timestamp),
            updatedByDeviceId: deviceId,
          ),
        );
  }

  Student _toDomain(StudentRow row) {
    return Student(
      id: row.id,
      givenNames: row.givenNames,
      firstSurname: row.firstSurname,
      secondSurname: row.secondSurname,
      sex: row.sex,
      birthDate: row.birthDate,
    );
  }
}
