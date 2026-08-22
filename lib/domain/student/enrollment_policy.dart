import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';

enum EnrollmentViolation {
  groupMismatch,
  gradeNotOffered,
  outsideSchoolYear,
  overlapsExistingEnrollment,
  listNumberAlreadyAssigned,
}

abstract final class EnrollmentPolicy {
  static Set<EnrollmentViolation> validate({
    required Enrollment candidate,
    required TeachingGroup group,
    required SchoolYear schoolYear,
    required Iterable<Enrollment> existingStudentEnrollments,
    required Iterable<Enrollment> existingGroupEnrollments,
  }) {
    final violations = <EnrollmentViolation>{};

    if (candidate.groupId != group.id) {
      violations.add(EnrollmentViolation.groupMismatch);
    }

    if (!group.acceptsGrade(candidate.grade)) {
      violations.add(EnrollmentViolation.gradeNotOffered);
    }

    final candidateEnd = candidate.endsOn;
    if (!schoolYear.contains(candidate.startsOn) ||
        (candidateEnd != null && !schoolYear.contains(candidateEnd))) {
      violations.add(EnrollmentViolation.outsideSchoolYear);
    }

    final hasOverlap = existingStudentEnrollments.any(
      (existing) =>
          existing.id != candidate.id &&
          existing.studentId == candidate.studentId &&
          existing.overlaps(candidate),
    );
    if (hasOverlap) {
      violations.add(EnrollmentViolation.overlapsExistingEnrollment);
    }

    final hasListNumberConflict = existingGroupEnrollments.any(
      (existing) =>
          existing.id != candidate.id &&
          existing.groupId == candidate.groupId &&
          existing.studentId != candidate.studentId &&
          existing.listNumber == candidate.listNumber &&
          existing.overlaps(candidate),
    );
    if (hasListNumberConflict) {
      violations.add(EnrollmentViolation.listNumberAlreadyAssigned);
    }

    return Set<EnrollmentViolation>.unmodifiable(violations);
  }
}
