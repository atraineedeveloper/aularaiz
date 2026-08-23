import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:drift/drift.dart';

final class DriftSchoolSetupRepository implements SchoolSetupRepository {
  DriftSchoolSetupRepository(this.database);

  final AppDatabase database;

  @override
  Future<bool> hasInitialSetup() async => (await listSetups()).isNotEmpty;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async {
    final setups = await listSetups();
    return setups.isEmpty ? null : setups.first;
  }

  @override
  Future<List<InitialSchoolSetup>> listSetups() async {
    final contexts = await database.select(database.schoolContexts).get();
    final result = <InitialSchoolSetup>[];
    for (final context in contexts) {
      final setup = await _loadContext(
        schoolId: context.schoolId,
        schoolYearId: context.schoolYearId,
      );
      if (setup != null) result.add(setup);
    }
    result.sort((left, right) => left.school.name.compareTo(right.school.name));
    return List<InitialSchoolSetup>.unmodifiable(result);
  }

  @override
  Future<InitialSchoolSetup?> loadForSchool(String schoolId) async {
    final context =
        await (database.select(database.schoolContexts)
              ..where((table) => table.schoolId.equals(schoolId))
              ..limit(1))
            .getSingleOrNull();
    if (context == null) return null;
    return _loadContext(
      schoolId: context.schoolId,
      schoolYearId: context.schoolYearId,
    );
  }

  @override
  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  }) async {
    await database.transaction(() async {
      await database
          .into(database.schools)
          .insert(
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

      await database
          .into(database.schoolYears)
          .insert(
            SchoolYearsCompanion(
              id: Value(schoolYear.id),
              label: Value(schoolYear.label),
              startsOn: Value(schoolYear.startsOn),
              endsOn: Value(schoolYear.endsOn),
            ),
          );

      await database
          .into(database.schoolContexts)
          .insert(
            SchoolContextsCompanion(
              schoolId: Value(school.id),
              schoolYearId: Value(schoolYear.id),
            ),
          );
    });
  }

  @override
  Future<void> updateSchool(School school) async {
    final updated =
        await (database.update(database.schools)
              ..where((table) => table.id.equals(school.id)))
            .write(
              SchoolsCompanion(
                name: Value(school.name),
                cct: Value(school.cct),
                organization: Value(school.organization),
                state: Value(school.state),
                municipality: Value(school.municipality),
                locality: Value(school.locality),
              ),
            );
    if (updated != 1) {
      throw StateError('School does not exist.');
    }
  }

  Future<InitialSchoolSetup?> _loadContext({
    required String schoolId,
    required String schoolYearId,
  }) async {
    final schoolRow =
        await (database.select(database.schools)
              ..where((table) => table.id.equals(schoolId))
              ..limit(1))
            .getSingleOrNull();
    final schoolYearRow =
        await (database.select(database.schoolYears)
              ..where((table) => table.id.equals(schoolYearId))
              ..limit(1))
            .getSingleOrNull();
    if (schoolRow == null || schoolYearRow == null) return null;

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
}
