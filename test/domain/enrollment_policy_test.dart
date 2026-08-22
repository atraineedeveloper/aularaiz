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
      startsOn: DateTime(2026, 9),
    );

    expect(
      EnrollmentPolicy.validate(
        candidate: candidate,
        group: group,
        schoolYear: schoolYear,
        existingEnrollments: const <Enrollment>[],
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
      startsOn: DateTime(2026, 9),
    );

    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingEnrollments: const <Enrollment>[],
    );

    expect(violations, contains(EnrollmentViolation.gradeNotOffered));
  });

  test('overlapping enrollment for the same student is rejected', () {
    final existing = Enrollment(
      id: 'enrollment-old',
      studentId: 'student-1',
      groupId: 'group-old',
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2026, 10, 15),
    );
    final candidate = Enrollment(
      id: 'enrollment-new',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.second,
      startsOn: DateTime(2026, 10, 15),
    );

    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingEnrollments: <Enrollment>[existing],
    );

    expect(
      violations,
      contains(EnrollmentViolation.overlapsExistingEnrollment),
    );
  });

  test('enrollment dates must start and end inside the school year', () {
    final candidate = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 8, 30),
      endsOn: DateTime(2027, 7, 16),
    );

    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingEnrollments: const <Enrollment>[],
    );

    expect(violations, contains(EnrollmentViolation.outsideSchoolYear));
  });
}
