import 'package:aularaiz/domain/education/nem_phase.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';

final class TeachingGroup {
  TeachingGroup({
    required this.id,
    required this.schoolId,
    required this.schoolYearId,
    required this.name,
    required Set<PrimaryGrade> grades,
  }) : grades = Set<PrimaryGrade>.unmodifiable(grades) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Group id cannot be empty.');
    }
    if (schoolId.trim().isEmpty) {
      throw ArgumentError.value(
        schoolId,
        'schoolId',
        'School id cannot be empty.',
      );
    }
    if (schoolYearId.trim().isEmpty) {
      throw ArgumentError.value(
        schoolYearId,
        'schoolYearId',
        'School year id cannot be empty.',
      );
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Group name cannot be empty.');
    }
    if (grades.isEmpty) {
      throw ArgumentError.value(
        grades,
        'grades',
        'A teaching group must contain at least one grade.',
      );
    }
  }

  final String id;
  final String schoolId;
  final String schoolYearId;
  final String name;
  final Set<PrimaryGrade> grades;

  bool get isMultigrade => grades.length > 1;

  Set<NemPhase> get phases => Set<NemPhase>.unmodifiable(
        grades.map((grade) => grade.phase),
      );
}
