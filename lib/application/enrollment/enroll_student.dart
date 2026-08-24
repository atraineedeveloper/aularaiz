import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/enrollment_policy.dart';

sealed class EnrollStudentResult {
  const EnrollStudentResult();
}

final class EnrollStudentSucceeded extends EnrollStudentResult {
  const EnrollStudentSucceeded();
}

enum EnrollmentReference { student, teachingGroup, schoolYear }

final class EnrollStudentMissingReference extends EnrollStudentResult {
  const EnrollStudentMissingReference(this.reference);

  final EnrollmentReference reference;
}

final class EnrollStudentRejected extends EnrollStudentResult {
  EnrollStudentRejected(Set<EnrollmentViolation> violations)
    : violations = Set<EnrollmentViolation>.unmodifiable(violations);

  final Set<EnrollmentViolation> violations;
}

final class EnrollStudent {
  const EnrollStudent({
    required this.enrollmentRepository,
    required this.schoolYearRepository,
    required this.studentRepository,
    required this.teachingGroupRepository,
  });

  final EnrollmentRepository enrollmentRepository;
  final SchoolYearRepository schoolYearRepository;
  final StudentRepository studentRepository;
  final TeachingGroupRepository teachingGroupRepository;

  Future<EnrollStudentResult> validate(Enrollment candidate) async {
    final student = await studentRepository.findById(candidate.studentId);
    if (student == null) {
      return const EnrollStudentMissingReference(EnrollmentReference.student);
    }

    final group = await teachingGroupRepository.findById(candidate.groupId);
    if (group == null) {
      return const EnrollStudentMissingReference(
        EnrollmentReference.teachingGroup,
      );
    }

    final schoolYear = await schoolYearRepository.findById(group.schoolYearId);
    if (schoolYear == null) {
      return const EnrollStudentMissingReference(
        EnrollmentReference.schoolYear,
      );
    }

    final existingStudentEnrollments = await enrollmentRepository
        .findByStudentId(candidate.studentId);
    final existingGroupEnrollments = await enrollmentRepository.findByGroupId(
      candidate.groupId,
    );
    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingStudentEnrollments: existingStudentEnrollments,
      existingGroupEnrollments: existingGroupEnrollments,
    );

    if (violations.isNotEmpty) {
      return EnrollStudentRejected(violations);
    }

    return const EnrollStudentSucceeded();
  }

  Future<EnrollStudentResult> call(Enrollment candidate) async {
    final validation = await validate(candidate);
    if (validation is! EnrollStudentSucceeded) return validation;

    await enrollmentRepository.save(candidate);
    return validation;
  }
}
