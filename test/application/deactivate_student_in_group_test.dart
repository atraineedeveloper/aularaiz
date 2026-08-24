import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/student/deactivate_student_in_group.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preview plans deactivation without persisting', () async {
    final repository = _MemoryEnrollmentRepository([_activeEnrollment()]);
    final useCase = DeactivateStudentInGroup(enrollmentRepository: repository);

    final plan = await useCase.preview(
      studentId: 'student-1',
      groupId: 'group-1',
      endsOn: DateTime(2026, 9, 15),
    );

    expect(plan.currentEnrollment.endsOn, isNull);
    expect(plan.endsOn, DateTime(2026, 9, 15));
    expect(repository.saveCount, 0);
  });

  test(
    'apply persists deactivation and clamps dates before enrollment start',
    () async {
      final repository = _MemoryEnrollmentRepository([_activeEnrollment()]);
      final useCase = DeactivateStudentInGroup(
        enrollmentRepository: repository,
      );

      final plan = await useCase(
        studentId: 'student-1',
        groupId: 'group-1',
        endsOn: DateTime(2026, 7, 1),
      );

      expect(plan.endsOn, DateTime(2026, 8, 1));
      expect(repository.saveCount, 1);
      expect(repository.values.single.endsOn, DateTime(2026, 8, 1));
    },
  );

  test('student without active enrollment is rejected', () async {
    final repository = _MemoryEnrollmentRepository([
      Enrollment(
        id: 'enrollment-1',
        studentId: 'student-1',
        groupId: 'group-1',
        grade: PrimaryGrade.first,
        listNumber: 1,
        startsOn: DateTime(2026, 8, 1),
        endsOn: DateTime(2026, 8, 31),
      ),
    ]);
    final useCase = DeactivateStudentInGroup(enrollmentRepository: repository);

    expect(
      () => useCase.preview(
        studentId: 'student-1',
        groupId: 'group-1',
        endsOn: DateTime(2026, 9, 15),
      ),
      throwsStateError,
    );
  });
}

Enrollment _activeEnrollment() => Enrollment(
  id: 'enrollment-1',
  studentId: 'student-1',
  groupId: 'group-1',
  grade: PrimaryGrade.first,
  listNumber: 1,
  startsOn: DateTime(2026, 8, 1),
);

final class _MemoryEnrollmentRepository implements EnrollmentRepository {
  _MemoryEnrollmentRepository(List<Enrollment> values)
    : values = List<Enrollment>.of(values);

  final List<Enrollment> values;
  int saveCount = 0;

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async =>
      values.where((enrollment) => enrollment.groupId == groupId).toList();

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async =>
      values.where((enrollment) => enrollment.studentId == studentId).toList();

  @override
  Future<void> save(Enrollment enrollment) async {
    saveCount += 1;
    final index = values.indexWhere((value) => value.id == enrollment.id);
    if (index == -1) {
      values.add(enrollment);
    } else {
      values[index] = enrollment;
    }
  }
}
