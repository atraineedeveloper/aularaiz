import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/enrollment/enroll_student.dart';
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
    name: '1A',
    grades: <PrimaryGrade>{PrimaryGrade.first},
  );

  test('valid enrollment is persisted', () async {
    final enrollments = _FakeEnrollmentRepository();
    final useCase = EnrollStudent(
      enrollmentRepository: enrollments,
      schoolYearRepository: _FakeSchoolYearRepository(schoolYear),
      teachingGroupRepository: _FakeTeachingGroupRepository(group),
    );
    final candidate = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 9),
    );

    final result = await useCase(candidate);

    expect(result, isA<EnrollStudentSucceeded>());
    expect(enrollments.saved, same(candidate));
  });

  test('missing teaching group prevents persistence', () async {
    final enrollments = _FakeEnrollmentRepository();
    final useCase = EnrollStudent(
      enrollmentRepository: enrollments,
      schoolYearRepository: _FakeSchoolYearRepository(schoolYear),
      teachingGroupRepository: _FakeTeachingGroupRepository(null),
    );
    final candidate = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: 'missing-group',
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 9),
    );

    final result = await useCase(candidate);

    expect(result, isA<EnrollStudentMissingReference>());
    expect(
      (result as EnrollStudentMissingReference).reference,
      EnrollmentReference.teachingGroup,
    );
    expect(enrollments.saved, isNull);
  });

  test('domain policy rejection prevents persistence', () async {
    final existing = Enrollment(
      id: 'existing',
      studentId: 'student-1',
      groupId: 'old-group',
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2026, 10),
    );
    final enrollments = _FakeEnrollmentRepository(<Enrollment>[existing]);
    final useCase = EnrollStudent(
      enrollmentRepository: enrollments,
      schoolYearRepository: _FakeSchoolYearRepository(schoolYear),
      teachingGroupRepository: _FakeTeachingGroupRepository(group),
    );
    final candidate = Enrollment(
      id: 'candidate',
      studentId: 'student-1',
      groupId: group.id,
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 9, 15),
    );

    final result = await useCase(candidate);

    expect(result, isA<EnrollStudentRejected>());
    expect(
      (result as EnrollStudentRejected).violations,
      contains(EnrollmentViolation.overlapsExistingEnrollment),
    );
    expect(enrollments.saved, isNull);
  });
}

final class _FakeEnrollmentRepository implements EnrollmentRepository {
  _FakeEnrollmentRepository([List<Enrollment>? existing])
    : _existing = existing ?? <Enrollment>[];

  final List<Enrollment> _existing;
  Enrollment? saved;

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async {
    return _existing
        .where((enrollment) => enrollment.studentId == studentId)
        .toList(growable: false);
  }

  @override
  Future<void> save(Enrollment enrollment) async {
    saved = enrollment;
  }
}

final class _FakeSchoolYearRepository implements SchoolYearRepository {
  const _FakeSchoolYearRepository(this.schoolYear);

  final SchoolYear? schoolYear;

  @override
  Future<SchoolYear?> findById(String id) async {
    final value = schoolYear;
    return value?.id == id ? value : null;
  }
}

final class _FakeTeachingGroupRepository implements TeachingGroupRepository {
  const _FakeTeachingGroupRepository(this.group);

  final TeachingGroup? group;

  @override
  Future<TeachingGroup?> findById(String id) async {
    final value = group;
    return value?.id == id ? value : null;
  }
}
