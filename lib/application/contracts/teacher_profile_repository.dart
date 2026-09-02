import 'package:aularaiz/domain/teacher/teacher_profile.dart';

/// Persists the single local teacher profile of this installation.
///
/// The profile is installation-scoped and must survive school creation,
/// school deletion and contract changes.
abstract interface class TeacherProfileRepository {
  Future<TeacherProfile?> load();

  Future<void> save(TeacherProfile profile);
}
