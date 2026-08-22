import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:drift/drift.dart';

final class DriftSchoolSetupRepository implements SchoolSetupRepository {
  DriftSchoolSetupRepository(this.database);

  final AppDatabase database;

  @override
  Future<bool> hasInitialSetup() async {
    final school = await (database.select(database.schools)..limit(1)).getSingleOrNull();
    final schoolYear = await (database.select(database.schoolYears)..limit(1)).getSingleOrNull();
    return school != null && schoolYear != null;
  }

  @override
  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  }) async {
    await database.transaction(() async {
      await database.into(database.schools).insert(
        SchoolsCompanion(
          id: Value(school.id),
          name: Value(school.name),
          cct: Value(school.cct),
          organization: Value(school.organization),
          state: Value(school.state),
          municipality: Value(school.municipality),
          locality: Value(school.locality),
        ),
      );

      await database.into(database.schoolYears).insert(
        SchoolYearsCompanion(
          id: Value(schoolYear.id),
          label: Value(schoolYear.label),
          startsOn: Value(schoolYear.startsOn),
          endsOn: Value(schoolYear.endsOn),
        ),
      );
    });
  }
}
