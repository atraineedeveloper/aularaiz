import 'package:aularaiz/domain/school/teaching_group.dart';

abstract interface class TeachingGroupRepository {
  Future<TeachingGroup?> findById(String id);

  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId);

  Future<void> save(TeachingGroup group);
}
