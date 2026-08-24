import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/domain/student/enrollment.dart';

final class DeactivateStudentPlan {
  const DeactivateStudentPlan({
    required this.currentEnrollment,
    required this.updatedEnrollment,
  });

  final Enrollment currentEnrollment;
  final Enrollment updatedEnrollment;

  DateTime get endsOn => updatedEnrollment.endsOn!;
}

final class DeactivateStudentInGroup {
  const DeactivateStudentInGroup({
    required EnrollmentRepository enrollmentRepository,
  }) : _enrollmentRepository = enrollmentRepository;

  final EnrollmentRepository _enrollmentRepository;

  Future<DeactivateStudentPlan> preview({
    required String studentId,
    required String groupId,
    required DateTime endsOn,
  }) async {
    final normalizedStudentId = studentId.trim();
    final normalizedGroupId = groupId.trim();
    if (normalizedStudentId.isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Student id cannot be empty.',
      );
    }
    if (normalizedGroupId.isEmpty) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Group id cannot be empty.',
      );
    }

    final enrollments = await _enrollmentRepository.findByGroupId(
      normalizedGroupId,
    );
    final active =
        enrollments
            .where(
              (enrollment) =>
                  enrollment.studentId == normalizedStudentId &&
                  enrollment.endsOn == null,
            )
            .toList(growable: false)
          ..sort((left, right) => right.startsOn.compareTo(left.startsOn));
    if (active.isEmpty) {
      throw StateError('Student has no active enrollment in this group.');
    }

    final current = active.first;
    final normalizedEnd = DateTime(endsOn.year, endsOn.month, endsOn.day);
    final effectiveEnd = normalizedEnd.isBefore(current.startsOn)
        ? current.startsOn
        : normalizedEnd;
    final updated = Enrollment(
      id: current.id,
      studentId: current.studentId,
      groupId: current.groupId,
      grade: current.grade,
      listNumber: current.listNumber,
      startsOn: current.startsOn,
      endsOn: effectiveEnd,
    );

    return DeactivateStudentPlan(
      currentEnrollment: current,
      updatedEnrollment: updated,
    );
  }

  Future<DeactivateStudentPlan> call({
    required String studentId,
    required String groupId,
    required DateTime endsOn,
  }) async {
    final plan = await preview(
      studentId: studentId,
      groupId: groupId,
      endsOn: endsOn,
    );
    await _enrollmentRepository.save(plan.updatedEnrollment);
    return plan;
  }
}
