import 'package:aularaiz/application/contracts/teacher_profile_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/teacher/teacher_profile.dart';
import 'package:drift/drift.dart';

final class DriftTeacherProfileRepository
    implements TeacherProfileRepository {
  DriftTeacherProfileRepository(this.database);

  final AppDatabase database;

  @override
  Future<TeacherProfile?> load() async {
    final row =
        await (database.select(database.teacherProfiles)
              ..where((table) => table.id.equals(TeacherProfile.localProfileId))
              ..limit(1))
            .getSingleOrNull();
    return TeacherProfile.fromStorage(row?.id, row?.fullName);
  }

  @override
  Future<void> save(TeacherProfile profile) async {
    await database
        .into(database.teacherProfiles)
        .insertOnConflictUpdate(
          TeacherProfilesCompanion(
            id: Value(profile.id),
            fullName: Value(profile.fullName),
          ),
        );
  }
}
