import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/project/create_activity.dart';
import 'package:aularaiz/application/project/create_project.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter/foundation.dart';

export 'package:aularaiz/features/projects/presentation/projects_localization.dart';

final class ProjectsController extends ChangeNotifier {
  ProjectsController({
    required ProjectRepository projectRepository,
    required ActivityRepository activityRepository,
    required CreateProject createProject,
    required CreateActivity createActivity,
  }) : _projectRepository = projectRepository,
       _activityRepository = activityRepository,
       _createProject = createProject,
       _createActivity = createActivity;

  final ProjectRepository _projectRepository;
  final ActivityRepository _activityRepository;
  final CreateProject _createProject;
  final CreateActivity _createActivity;

  TeachingGroup? _group;
  List<Project> _projects = const [];
  Map<String, List<Activity>> _activities = const {};
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  TeachingGroup? get group => _group;
  List<Project> get projects => _projects;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;

  List<Activity> activitiesFor(String projectId) {
    return _activities[projectId] ?? const [];
  }

  Future<void> load(TeachingGroup group) async {
    _group = group;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _reload();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createProject({
    required String title,
    required ProjectMethodology methodology,
    required Set<FormativeField> formativeFields,
    required Set<ArticulatingAxis> articulatingAxes,
    required Set<PrimaryGrade> targetGrades,
  }) async {
    final group = _group;
    if (group == null || _isSaving) return false;
    return _mutate(() async {
      await _createProject(
        groupId: group.id,
        title: title,
        methodology: methodology,
        formativeFields: formativeFields,
        articulatingAxes: articulatingAxes,
        targetGrades: targetGrades,
      );
    });
  }

  Future<bool> setLifecycle(Project project, ProjectLifecycle lifecycle) async {
    if (_isSaving || project.lifecycle == lifecycle) return false;
    return _mutate(() async {
      await _projectRepository.save(
        Project(
          id: project.id,
          groupId: project.groupId,
          title: project.title,
          lifecycle: lifecycle,
          methodology: project.methodology,
          formativeFields: project.formativeFields,
          articulatingAxes: project.articulatingAxes,
          targetGrades: project.targetGrades,
        ),
      );
    });
  }

  Future<bool> createActivity({
    required Project project,
    required String title,
    required FormativeField formativeField,
    required Set<PrimaryGrade> targetGrades,
  }) async {
    if (_isSaving) return false;
    return _mutate(() async {
      await _createActivity(
        projectId: project.id,
        title: title,
        formativeField: formativeField,
        targetGrades: targetGrades,
        rosterDate: DateTime.now(),
      );
    });
  }

  Future<bool> _mutate(Future<void> Function() mutation) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await mutation();
      await _reload();
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reload() async {
    final group = _group;
    if (group == null) return;
    final projects = await _projectRepository.listForGroup(group.id);
    final activities = <String, List<Activity>>{};
    for (final project in projects) {
      activities[project.id] = await _activityRepository.listForProject(
        project.id,
      );
    }
    _projects = List<Project>.unmodifiable(projects);
    _activities = Map<String, List<Activity>>.unmodifiable(activities);
  }
}
