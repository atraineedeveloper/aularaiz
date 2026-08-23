import 'package:aularaiz/application/contracts/student_enrollment_writer.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:drift/drift.dart';

final class DriftStudentEnrollmentWriter implements StudentEnrollmentWriter {
  DriftStudentEnrollmentWriter(this.database);

  final AppDatabase database;

  @override
  Future<void> saveNewStudentWithEnrollment({
    required Student student,
    required Enrollment enrollment,
  }) async {
    await database.transaction(() async {
      await database
          .into(database.students)
          .insert(
            StudentsCompanion(
              id: Value(student.id),
              givenNames: Value(student.givenNames),
              firstSurname: Value(student.firstSurname),
              secondSurname: Value(student.secondSurname),
              sex: Value(student.sex),
              birthDate: Value(student.birthDate),
            ),
          );
      await database
          .into(database.enrollments)
          .insert(
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
    });
  }
}
