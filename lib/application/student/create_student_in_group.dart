import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_enrollment_writer.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/enrollment_policy.dart';
import 'package:aularaiz/domain/student/student.dart';

sealed class CreateStudentInGroupResult {
  const CreateStudentInGroupResult();
}

final class CreateStudentInGroupSucceeded extends CreateStudentInGroupResult {
  const CreateStudentInGroupSucceeded(this.student);

  final Student student;
}

final class CreateStudentInGroupRejected extends CreateStudentInGroupResult {
  CreateStudentInGroupRejected(Set<EnrollmentViolation> violations)
    : violations = Set<EnrollmentViolation>.unmodifiable(violations);

  final Set<EnrollmentViolation> violations;
}

final class CreateStudentInGroup {
  CreateStudentInGroup({
    required TeachingGroupRepository teachingGroupRepository,
    required SchoolYearRepository schoolYearRepository,
    required EnrollmentRepository enrollmentRepository,
    required StudentEnrollmentWriter writer,
    required IdGenerator idGenerator,
  }) : _teachingGroupRepository = teachingGroupRepository,
       _schoolYearRepository = schoolYearRepository,
       _enrollmentRepository = enrollmentRepository,
       _writer = writer,
       _idGenerator = idGenerator;

  final TeachingGroupRepository _teachingGroupRepository;
  final SchoolYearRepository _schoolYearRepository;
  final EnrollmentRepository _enrollmentRepository;
  final StudentEnrollmentWriter _writer;
  final IdGenerator _idGenerator;

  Future<CreateStudentInGroupResult> call({
    required String groupId,
    required String givenNames,
    required String firstSurname,
    String? secondSurname,
    DateTime? birthDate,
    required PrimaryGrade grade,
    required int listNumber,
  }) async {
    final group = await _teachingGroupRepository.findById(groupId);
    if (group == null) {
      throw StateError('Teaching group does not exist.');
    }
    final schoolYear = await _schoolYearRepository.findById(group.schoolYearId);
    if (schoolYear == null) {
      throw StateError('School year does not exist.');
    }

    final student = Student(
      id: _idGenerator.newId(),
      givenNames: givenNames,
      firstSurname: firstSurname,
      secondSurname: _optional(secondSurname),
      birthDate: birthDate,
    );
    final enrollment = Enrollment(
      id: _idGenerator.newId(),
      studentId: student.id,
      groupId: group.id,
      grade: grade,
      listNumber: listNumber,
      startsOn: schoolYear.startsOn,
    );
    final groupEnrollments = await _enrollmentRepository.findByGroupId(
      group.id,
    );
    final violations = EnrollmentPolicy.validate(
      candidate: enrollment,
      group: group,
      schoolYear: schoolYear,
      existingStudentEnrollments: const <Enrollment>[],
      existingGroupEnrollments: groupEnrollments,
    );

    if (violations.isNotEmpty) {
      return CreateStudentInGroupRejected(violations);
    }

    await _writer.saveNewStudentWithEnrollment(
      student: student,
      enrollment: enrollment,
    );
    return CreateStudentInGroupSucceeded(student);
  }

  String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
