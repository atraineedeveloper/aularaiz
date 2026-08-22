import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:drift/drift.dart';

final class DriftEnrollmentRepository implements EnrollmentRepository {
  DriftEnrollmentRepository(this.database);

  final AppDatabase database;

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async {
    final rows = await (database.select(
      database.enrollments,
    )..where((table) => table.studentId.equals(studentId))).get();

    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async {
    final rows = await (database.select(
      database.enrollments,
    )..where((table) => table.groupId.equals(groupId))).get();

    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> save(Enrollment enrollment) async {
    await database
        .into(database.enrollments)
        .insertOnConflictUpdate(
          EnrollmentsCompanion(
            id: Value(enrollment.id),
            studentId: Value(enrollment.studentId),
            groupId: Value(enrollment.groupId),
            grade: Value(enrollment.grade),
            listNumber: Value(enrollment.listNumber),
            startsOn: Value(enrollment.startsOn),
            endsOn: Value(enrollment.endsOn),
          ),
        );
  }

  Enrollment _toDomain(EnrollmentRow row) {
    return Enrollment(
      id: row.id,
      studentId: row.studentId,
      groupId: row.groupId,
      grade: row.grade,
      listNumber: row.listNumber,
      startsOn: row.startsOn,
      endsOn: row.endsOn,
    );
  }
}
