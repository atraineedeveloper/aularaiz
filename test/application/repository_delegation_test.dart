import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group deletion extension delegates without recursion', () async {
    final implementation = _GroupRepository();
    final contract = implementation as TeachingGroupRepository;

    await contract.deleteGroup('group-1');

    expect(implementation.deletedId, 'group-1');
  });

  test('activity deletion extension delegates without recursion', () async {
    final implementation = _ActivityRepository();
    final contract = implementation as ActivityRepository;

    await contract.deleteActivity('activity-1');

    expect(implementation.deletedId, 'activity-1');
  });
}

final class _GroupRepository
    implements TeachingGroupRepository, DeletableTeachingGroupRepository {
  String? deletedId;

  @override
  Future<void> deleteGroup(String groupId) async => deletedId = groupId;

  @override
  Future<TeachingGroup?> findById(String id) async => null;

  @override
  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId) async =>
      const [];

  @override
  Future<void> save(TeachingGroup group) async {}
}

final class _ActivityRepository
    implements ActivityRepository, DeletableActivityRepository {
  String? deletedId;

  @override
  Future<void> deleteActivity(String activityId) async =>
      deletedId = activityId;

  @override
  Future<Activity?> findById(String id) async => null;

  @override
  Future<List<Activity>> listForProject(String projectId) async => const [];

  @override
  Future<void> save(Activity activity) async {}
}
