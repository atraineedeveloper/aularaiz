import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/teacher/teaching_role.dart';

final class CreateTeachingGroup {
  CreateTeachingGroup({
    required TeachingGroupRepository repository,
    required IdGenerator idGenerator,
  }) : _repository = repository,
       _idGenerator = idGenerator;

  final TeachingGroupRepository _repository;
  final IdGenerator _idGenerator;

  Future<TeachingGroup> call({
    required String schoolId,
    required String schoolYearId,
    required String name,
    required Set<PrimaryGrade> grades,
    String? shift,
    ClassSchedule? schedule,
    TeachingContract? contract,
    TeachingRole? teachingRole,
  }) async {
    final existing = await _repository.listForSchoolYear(schoolYearId);
    final validatedContract = _validatedContract(
      schoolId: schoolId,
      existing: existing,
      contract: contract,
    );

    final group = TeachingGroup(
      id: _idGenerator.newId(),
      schoolId: schoolId,
      schoolYearId: schoolYearId,
      name: name,
      grades: grades,
      shift: shift,
      schedule: schedule,
      contract: validatedContract,
      teachingRole: teachingRole,
    );

    await _repository.save(group);
    return group;
  }

  TeachingContract? _validatedContract({
    required String schoolId,
    required List<TeachingGroup> existing,
    required TeachingContract? contract,
  }) {
    if (contract == null) return null;

    for (final group in existing) {
      if (group.schoolId != schoolId) continue;
      final other = group.contract;
      if (other == null) continue;
      final overlaps =
          !contract.startsOn.isAfter(other.endsOn) &&
          !contract.endsOn.isBefore(other.startsOn);
      if (overlaps) {
        throw StateError(
          'Teaching contracts for the same school and school year '
          'cannot overlap.',
        );
      }
    }

    return contract;
  }
}
