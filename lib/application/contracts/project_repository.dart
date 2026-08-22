import 'package:aularaiz/domain/project/project.dart';

abstract interface class ProjectRepository {
  Future<Project?> findById(String id);

  Future<List<Project>> listForGroup(String groupId);

  Future<void> save(Project project);
}
