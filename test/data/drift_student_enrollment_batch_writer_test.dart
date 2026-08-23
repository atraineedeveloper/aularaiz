import 'package:aularaiz/application/contracts/student_enrollment_batch_writer.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_student_enrollment_batch_writer.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftStudentEnrollmentBatchWriter writer;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    writer = DriftStudentEnrollmentBatchWriter(database);

    await database
        .into(database.schools)
        .insert(
          SchoolsCompanion(
            id: const Value('school-1'),
            name: const Value('Primaria de Prueba'),
            organization: const Value(SchoolOrganization.complete),
          ),
        );
    await database
        .into(database.schoolYears)
        .insert(
          SchoolYearsCompanion(
            id: const Value('year-1'),
            label: const Value('2026-2027'),
            startsOn: Value(DateTime(2026, 8, 1)),
            endsOn: Value(DateTime(2027, 7, 31)),
          ),
        );
    await database
        .into(database.teachingGroups)
        .insert(
          const TeachingGroupsCompanion(
            id: Value('group-1'),
            schoolId: Value('school-1'),
            schoolYearId: Value('year-1'),
            name: Value('5° A'),
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test('rolls back earlier rows when a later row fails', () async {
    final firstStudent = Student(
      id: 'student-1',
      givenNames: 'Ana',
      firstSurname: 'Pérez',
    );
    final secondStudentWithDuplicateId = Student(
      id: 'student-1',
      givenNames: 'Bruno',
      firstSurname: 'Díaz',
    );

    final entries = [
      NewStudentEnrollment(
        student: firstStudent,
        enrollment: Enrollment(
          id: 'enrollment-1',
          studentId: firstStudent.id,
          groupId: 'group-1',
          grade: PrimaryGrade.fifth,
          listNumber: 1,
          startsOn: DateTime(2026, 8, 1),
        ),
      ),
      NewStudentEnrollment(
        student: secondStudentWithDuplicateId,
        enrollment: Enrollment(
          id: 'enrollment-2',
          studentId: secondStudentWithDuplicateId.id,
          groupId: 'group-1',
          grade: PrimaryGrade.fifth,
          listNumber: 2,
          startsOn: DateTime(2026, 8, 1),
        ),
      ),
    ];

    await expectLater(writer.saveBatch(entries), throwsA(anything));

    expect(await database.select(database.students).get(), isEmpty);
    expect(await database.select(database.enrollments).get(), isEmpty);
  });
}
