import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_enrollment_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_year_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/enrollment_policy.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftStudentRepository studentRepository;
  late DriftSchoolYearRepository schoolYearRepository;
  late DriftTeachingGroupRepository teachingGroupRepository;
  late DriftEnrollmentRepository enrollmentRepository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    studentRepository = DriftStudentRepository(database);
    schoolYearRepository = DriftSchoolYearRepository(database);
    teachingGroupRepository = DriftTeachingGroupRepository(database);
    enrollmentRepository = DriftEnrollmentRepository(database);

    await _seedSchoolContext(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('repositories reconstruct persisted domain objects', () async {
    final student = await studentRepository.findById('student-1');
    final schoolYear = await schoolYearRepository.findById('year-1');
    final group = await teachingGroupRepository.findById('group-1');

    expect(student, isNotNull);
    expect(student!.displayName, 'Ana Pérez');
    expect(student.birthDate, DateTime(2018, 9, 12));
    expect(student.ageOn(DateTime(2026, 9, 12)), 8);

    expect(schoolYear, isNotNull);
    expect(schoolYear!.label, '2026-2027');
    expect(schoolYear.contains(DateTime(2026, 9)), isTrue);

    expect(group, isNotNull);
    expect(
      group!.grades,
      containsAll(<PrimaryGrade>{PrimaryGrade.first, PrimaryGrade.second}),
    );
    expect(group.isMultigrade, isTrue);
    expect(group.shift, 'Matutino');
    expect(group.schedule?.startsAtMinutes, 8 * 60);
    expect(group.schedule?.endsAtMinutes, 13 * 60);
  });

  test('enroll student persists and round-trips through Drift', () async {
    final useCase = EnrollStudent(
      enrollmentRepository: enrollmentRepository,
      schoolYearRepository: schoolYearRepository,
      studentRepository: studentRepository,
      teachingGroupRepository: teachingGroupRepository,
    );
    final candidate = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: 'group-1',
      grade: PrimaryGrade.first,
      listNumber: 7,
      startsOn: DateTime(2026, 9),
    );

    final result = await useCase(candidate);

    expect(result, isA<EnrollStudentSucceeded>());

    final byStudent = await enrollmentRepository.findByStudentId('student-1');
    final byGroup = await enrollmentRepository.findByGroupId('group-1');
    final rawRow = await (database.select(
      database.enrollments,
    )..where((table) => table.id.equals(candidate.id))).getSingle();

    expect(byStudent, hasLength(1));
    expect(byStudent.single.id, candidate.id);
    expect(byStudent.single.grade, PrimaryGrade.first);
    expect(byStudent.single.listNumber, 7);
    expect(byGroup.map((item) => item.id), contains(candidate.id));
    expect(rawRow, isA<EnrollmentRow>());
    expect(rawRow.listNumber, 7);
  });

  test('persisted list number conflict is rejected by the use case', () async {
    await enrollmentRepository.save(
      Enrollment(
        id: 'existing-enrollment',
        studentId: 'student-2',
        groupId: 'group-1',
        grade: PrimaryGrade.second,
        listNumber: 7,
        startsOn: DateTime(2026, 9),
      ),
    );

    final useCase = EnrollStudent(
      enrollmentRepository: enrollmentRepository,
      schoolYearRepository: schoolYearRepository,
      studentRepository: studentRepository,
      teachingGroupRepository: teachingGroupRepository,
    );
    final candidate = Enrollment(
      id: 'candidate-enrollment',
      studentId: 'student-1',
      groupId: 'group-1',
      grade: PrimaryGrade.first,
      listNumber: 7,
      startsOn: DateTime(2026, 9),
    );

    final result = await useCase(candidate);

    expect(result, isA<EnrollStudentRejected>());
    expect(
      (result as EnrollStudentRejected).violations,
      contains(EnrollmentViolation.listNumberAlreadyAssigned),
    );
    expect(
      await enrollmentRepository.findByStudentId(candidate.studentId),
      isEmpty,
    );
  });
}

Future<void> _seedSchoolContext(AppDatabase database) async {
  await database
      .into(database.schools)
      .insert(
        const SchoolsCompanion(
          id: Value('school-1'),
          name: Value('Escuela Primaria'),
          organization: Value(SchoolOrganization.complete),
          state: Value('Tabasco'),
          municipality: Value('Centro'),
          locality: Value('Villahermosa'),
        ),
      );
  await database
      .into(database.schoolYears)
      .insert(
        SchoolYearsCompanion(
          id: const Value('year-1'),
          label: const Value('2026-2027'),
          startsOn: Value(DateTime(2026, 8, 31)),
          endsOn: Value(DateTime(2027, 7, 15)),
        ),
      );
  await database
      .into(database.teachingGroups)
      .insert(
        const TeachingGroupsCompanion(
          id: Value('group-1'),
          schoolId: Value('school-1'),
          schoolYearId: Value('year-1'),
          name: Value('1.º y 2.º A'),
          shift: Value('Matutino'),
          scheduleStartMinutes: Value(480),
          scheduleEndMinutes: Value(780),
        ),
      );
  await database
      .into(database.groupGrades)
      .insert(
        const GroupGradesCompanion(
          groupId: Value('group-1'),
          grade: Value(PrimaryGrade.first),
        ),
      );
  await database
      .into(database.groupGrades)
      .insert(
        const GroupGradesCompanion(
          groupId: Value('group-1'),
          grade: Value(PrimaryGrade.second),
        ),
      );
  await database
      .into(database.students)
      .insert(
        StudentsCompanion(
          id: const Value('student-1'),
          givenNames: const Value('Ana'),
          firstSurname: const Value('Pérez'),
          birthDate: Value(DateTime(2018, 9, 12)),
        ),
      );
  await database
      .into(database.students)
      .insert(
        const StudentsCompanion(
          id: Value('student-2'),
          givenNames: Value('Luis'),
          firstSurname: Value('Gómez'),
        ),
      );
}
