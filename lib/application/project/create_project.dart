import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';

final class CreateProject {
  CreateProject({required ProjectRepository repository, required IdGenerator idGenerator})
      : _repository = repository,
        _idGenerator = idGenerator;

  final ProjectRepository _repository;
  final IdGenerator _idGenerator;

  Future<Project> call({
    required String groupId,
    required String title,
    required ProjectMethodology methodology,
    Set<ArticulatingAxis> articulatingAxes = const <ArticulatingAxis>{},
    required Set<PrimaryGrade> targetGrades,
  }) async {
    final project = Project(
      id: _idGenerator.newId(),
      groupId: groupId,
      title: title,
      lifecycle: ProjectLifecycle.draft,
      methodology: methodology,
      articulatingAxes: articulatingAxes,
      targetGrades: targetGrades,
    );
    await _repository.save(project);
    return project;
  }
}
