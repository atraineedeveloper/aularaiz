import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';

final class Project {
  Project({
    required this.id,
    required this.groupId,
    required this.title,
    required this.lifecycle,
    required this.methodology,
    Set<ArticulatingAxis> articulatingAxes = const <ArticulatingAxis>{},
    required Set<PrimaryGrade> targetGrades,
  }) : articulatingAxes = Set<ArticulatingAxis>.unmodifiable(articulatingAxes),
       targetGrades = Set<PrimaryGrade>.unmodifiable(targetGrades) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Project id cannot be empty.');
    }
    if (groupId.trim().isEmpty) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Project group id cannot be empty.',
      );
    }
    if (title.trim().isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Project title cannot be empty.',
      );
    }
    if (targetGrades.isEmpty) {
      throw ArgumentError.value(
        targetGrades,
        'targetGrades',
        'Project must target at least one grade.',
      );
    }
  }

  final String id;
  final String groupId;
  final String title;
  final ProjectLifecycle lifecycle;
  final ProjectMethodology methodology;
  final Set<ArticulatingAxis> articulatingAxes;
  final Set<PrimaryGrade> targetGrades;

  bool allowsActivityGrades(Set<PrimaryGrade> grades) {
    return grades.isNotEmpty && targetGrades.containsAll(grades);
  }
}
