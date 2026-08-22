import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:drift/drift.dart';

final class DriftSchoolSetupRepository implements SchoolSetupRepository {
  DriftSchoolSetupRepository(this.database);

  final AppDatabase database;

  @override
  Future<bool> hasInitialSetup() async => (await loadInitialSetup()) != null;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async {
    final schoolRow = await (database.select(database.schools)..limit(1)).getSingleOrNull();
    final yearRows = await (database.select(database.schoolYears)
          ..orderBy([(table) => OrderingTerm.desc(table.startsOn)])
          ..limit(1))
        .get();

    if (schoolRow == null || yearRows.isEmpty) return null;
    final schoolYearRow = yearRows.single;

    return (
      school: School(
        id: schoolRow.id,
        name: schoolRow.name,
        cct: schoolRow.cct,
        organization: schoolRow.organization,
        state: schoolRow.state,
        municipality: schoolRow.municipality,
        locality: schoolRow.locality,
      ),
      schoolYear: SchoolYear(
        id: schoolYearRow.id,
        label: schoolYearRow.label,
        startsOn: schoolYearRow.startsOn,
        endsOn: schoolYearRow.endsOn,
      ),
    );
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
