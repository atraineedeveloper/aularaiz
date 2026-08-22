import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/project.dart';

enum ActivityViolation { projectMismatch, targetGradeOutsideProject }

abstract final class ActivityPolicy {
  static Set<ActivityViolation> validate({
    required Activity activity,
    required Project project,
  }) {
    final violations = <ActivityViolation>{};

    if (activity.projectId != project.id) {
      violations.add(ActivityViolation.projectMismatch);
    }
    if (!project.allowsActivityGrades(activity.targetGrades)) {
      violations.add(ActivityViolation.targetGradeOutsideProject);
    }

    return Set<ActivityViolation>.unmodifiable(violations);
  }
}
