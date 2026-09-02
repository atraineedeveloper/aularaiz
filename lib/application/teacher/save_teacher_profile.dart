import 'package:aularaiz/application/contracts/teacher_profile_repository.dart';
import 'package:aularaiz/domain/teacher/teacher_profile.dart';

/// Creates or updates the single local teacher profile.
///
/// Saving is an upsert on the fixed local profile id so repeated calls (for
/// example when the teacher registers a new school) never duplicate rows or
/// lose unrelated data.
final class SaveTeacherProfile {
  SaveTeacherProfile({required TeacherProfileRepository repository})
    : _repository = repository;

  final TeacherProfileRepository _repository;

  Future<TeacherProfile> call({required String fullName}) async {
    final trimmed = fullName.trim();
    final profile = TeacherProfile(
      id: TeacherProfile.localProfileId,
      fullName: trimmed,
    );
    await _repository.save(profile);
    return profile;
  }
}
