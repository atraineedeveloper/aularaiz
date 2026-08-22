import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/enrollment_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final schoolYear = SchoolYear(
    id: 'year-1',
    label: '2026-2027',
    startsOn: DateTime(2026, 8, 31),
    endsOn: DateTime(2027, 7, 15),
  );
  final group = TeachingGroup(
    id: 'group-1',
    schoolId: 'school-1',
    schoolYearId: schoolYear.id,
    name: 'Multigrado',
    grades: <PrimaryGrade>{PrimaryGrade.first, PrimaryGrade.second},
  );

  test('valid enrollment has no policy violations', () {
    final candidate = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.second,
      listNumber: 1,
      startsOn: DateTime(2026, 9),
    );

    expect(
      EnrollmentPolicy.validate(
        candidate: candidate,
        group: group,
        schoolYear: schoolYear,
        existingStudentEnrollments: const <Enrollment>[],
        existingGroupEnrollments: const <Enrollment>[],
      ),
      isEmpty,
    );
  });

  test('grade must be offered by the teaching group', () {
    final candidate = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.third,
      listNumber: 1,
      startsOn: DateTime(2026, 9),
    );

    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingStudentEnrollments: const <Enrollment>[],
      existingGroupEnrollments: const <Enrollment>[],
    );

    expect(violations, contains(EnrollmentViolation.gradeNotOffered));
  });

  test('overlapping enrollment for the same student is rejected', () {
    final existing = Enrollment(
      id: 'enrollment-old',
      studentId: 'student-1',
      groupId: 'group-old',
      grade: PrimaryGrade.first,
      listNumber: 2,
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2026, 10, 15),
    );
    final candidate = Enrollment(
      id: 'enrollment-new',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.second,
      listNumber: 1,
      startsOn: DateTime(2026, 10, 15),
    );

    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingStudentEnrollments: <Enrollment>[existing],
      existingGroupEnrollments: const <Enrollment>[],
    );

    expect(
      violations,
      contains(EnrollmentViolation.overlapsExistingEnrollment),
    );
  });

  test('active list number cannot be shared inside the same group', () {
    final existing = Enrollment(
      id: 'enrollment-existing',
      studentId: 'student-2',
      groupId: group.id,
      grade: PrimaryGrade.first,
      listNumber: 7,
      startsOn: DateTime(2026, 9),
    );
    final candidate = Enrollment(
      id: 'enrollment-candidate',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.second,
      listNumber: 7,
      startsOn: DateTime(2026, 9),
    );

    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingStudentEnrollments: const <Enrollment>[],
      existingGroupEnrollments: <Enrollment>[existing],
    );

    expect(
      violations,
      contains(EnrollmentViolation.listNumberAlreadyAssigned),
    );
  });

  test('a reused list number is allowed after the prior enrollment ends', () {
    final existing = Enrollment(
      id: 'enrollment-existing',
      studentId: 'student-2',
      groupId: group.id,
      grade: PrimaryGrade.first,
      listNumber: 7,
      startsOn: DateTime(2026, 9),
      endsOn: DateTime(2026, 10, 1),
    );
    final candidate = Enrollment(
      id: 'enrollment-candidate',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.second,
      listNumber: 7,
      startsOn: DateTime(2026, 10, 2),
    );

    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingStudentEnrollments: const <Enrollment>[],
      existingGroupEnrollments: <Enrollment>[existing],
    );

    expect(
      violations,
      isNot(contains(EnrollmentViolation.listNumberAlreadyAssigned)),
    );
  });

  test('enrollment dates must start and end inside the school year', () {
    final candidate = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.first,
      listNumber: 1,
      startsOn: DateTime(2026, 8, 30),
      endsOn: DateTime(2027, 7, 16),
    );

    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingStudentEnrollments: const <Enrollment>[],
      existingGroupEnrollments: const <Enrollment>[],
    );

    expect(violations, contains(EnrollmentViolation.outsideSchoolYear));
  });
}
