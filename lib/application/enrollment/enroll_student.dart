import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/enrollment_policy.dart';

sealed class EnrollStudentResult {
  const EnrollStudentResult();
}

final class EnrollStudentSucceeded extends EnrollStudentResult {
  const EnrollStudentSucceeded();
}

enum EnrollmentReference { teachingGroup, schoolYear }

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
    required EnrollmentRepository enrollmentRepository,
    required SchoolYearRepository schoolYearRepository,
    required TeachingGroupRepository teachingGroupRepository,
  }) : _enrollmentRepository = enrollmentRepository,
       _schoolYearRepository = schoolYearRepository,
       _teachingGroupRepository = teachingGroupRepository;

  final EnrollmentRepository _enrollmentRepository;
  final SchoolYearRepository _schoolYearRepository;
  final TeachingGroupRepository _teachingGroupRepository;

  Future<EnrollStudentResult> call(Enrollment candidate) async {
    final group = await _teachingGroupRepository.findById(candidate.groupId);
    if (group == null) {
      return const EnrollStudentMissingReference(
        EnrollmentReference.teachingGroup,
      );
    }

    final schoolYear = await _schoolYearRepository.findById(
      group.schoolYearId,
    );
    if (schoolYear == null) {
      return const EnrollStudentMissingReference(
        EnrollmentReference.schoolYear,
      );
    }

    final existing = await _enrollmentRepository.findByStudentId(
      candidate.studentId,
    );
    final violations = EnrollmentPolicy.validate(
      candidate: candidate,
      group: group,
      schoolYear: schoolYear,
      existingEnrollments: existing,
    );

    if (violations.isNotEmpty) {
      return EnrollStudentRejected(violations);
    }

    await _enrollmentRepository.save(candidate);
    return const EnrollStudentSucceeded();
  }
}
