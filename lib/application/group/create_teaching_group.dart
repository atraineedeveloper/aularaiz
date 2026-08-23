import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';

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
  }) async {
    final existing = await _repository.listForSchoolYear(schoolYearId);
    if (existing.any((group) => group.schoolId == schoolId)) {
      throw StateError(
        'A primary teacher can manage only one group for this school year.',
      );
    }

    final group = TeachingGroup(
      id: _idGenerator.newId(),
      schoolId: schoolId,
      schoolYearId: schoolYearId,
      name: name,
      grades: grades,
      shift: shift,
      schedule: schedule,
    );

    await _repository.save(group);
    return group;
  }
}
