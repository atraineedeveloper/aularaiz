import 'package:aularaiz/domain/project/activity.dart';

abstract interface class ActivityRepository {
  Future<Activity?> findById(String id);

  Future<List<Activity>> listForProject(String projectId);

  Future<void> save(Activity activity);
}
