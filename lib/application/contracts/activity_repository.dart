import 'package:aularaiz/domain/project/activity.dart';

abstract interface class ActivityRepository {
  Future<Activity?> findById(String id);

  Future<List<Activity>> listForProject(String projectId);

  Future<void> save(Activity activity);
}

abstract interface class DeletableActivityRepository {
  Future<void> deleteActivity(String activityId);
}

extension ActivityRepositoryDeletion on ActivityRepository {
  Future<void> deleteActivity(String activityId) {
    final repository = this;
    if (repository is DeletableActivityRepository) {
      return (repository as DeletableActivityRepository).deleteActivity(
        activityId,
      );
    }
    throw UnsupportedError(
      'This activity repository does not support deletion.',
    );
  }
}
