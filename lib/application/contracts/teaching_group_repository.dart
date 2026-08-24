import 'package:aularaiz/domain/school/teaching_group.dart';

abstract interface class TeachingGroupRepository {
  Future<TeachingGroup?> findById(String id);

  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId);

  Future<void> save(TeachingGroup group);
}

abstract interface class DeletableTeachingGroupRepository {
  Future<void> deleteGroup(String groupId);
}

extension TeachingGroupRepositoryDeletion on TeachingGroupRepository {
  Future<void> deleteGroup(String groupId) {
    final repository = this;
    if (repository is DeletableTeachingGroupRepository) {
      return repository.deleteGroup(groupId);
    }
    throw UnsupportedError('This group repository does not support deletion.');
  }
}
