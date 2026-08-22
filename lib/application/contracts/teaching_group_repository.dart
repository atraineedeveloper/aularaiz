import 'package:aularaiz/domain/school/teaching_group.dart';

abstract interface class TeachingGroupRepository {
  Future<TeachingGroup?> findById(String id);
}
