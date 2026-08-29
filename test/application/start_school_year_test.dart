import 'package:aularaiz/application/school_setup/start_school_year.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftSchoolSetupRepository repository;
  late _Ids ids;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSchoolSetupRepository(database);
    ids = _Ids();

    await repository.saveInitialSetup(
      school: School(
        id: 'school-1',
        name: 'Primaria Demo',
        organization: SchoolOrganization.complete,
      ),
      schoolYear: SchoolYear(
        id: 'year-1',
        label: '2026-2027',
        startsOn: DateTime(2026, 8, 31),
        endsOn: DateTime(2027, 7, 15),
      ),
    );
  });

  tearDown(() => database.close());

  test(
    'starts the next school year and keeps the previous one saved',
    () async {
      final start = StartSchoolYear(
        setupRepository: repository,
        starterRepository: repository,
        idGenerator: ids,
      );

      final year = await start(
        schoolId: 'school-1',
        schoolYearLabel: '2027-2028',
        startsOn: DateTime(2027, 8, 30),
        endsOn: DateTime(2028, 7, 14),
      );

      expect(year.label, '2027-2028');

      final activeSetup = await repository.loadForSchool('school-1');
      expect(activeSetup!.schoolYear.id, year.id);
      expect(activeSetup.schoolYear.label, '2027-2028');

      final yearRow = await database
          .customSelect("SELECT label FROM school_years WHERE id = 'year-1'")
          .getSingle();
      expect(yearRow.read<String>('label'), '2026-2027');
    },
  );

  test(
    'rejects a school year that does not start after the current one',
    () async {
      final start = StartSchoolYear(
        setupRepository: repository,
        starterRepository: repository,
        idGenerator: ids,
      );

      await expectLater(
        start(
          schoolId: 'school-1',
          schoolYearLabel: '2026-2027',
          startsOn: DateTime(2026, 8, 31),
          endsOn: DateTime(2027, 7, 15),
        ),
        throwsStateError,
      );
      await expectLater(
        start(
          schoolId: 'school-1',
          schoolYearLabel: '2025-2026',
          startsOn: DateTime(2025, 9, 1),
          endsOn: DateTime(2026, 7, 15),
        ),
        throwsStateError,
      );

      final activeSetup = await repository.loadForSchool('school-1');
      expect(activeSetup!.schoolYear.label, '2026-2027');
    },
  );
}

final class _Ids implements IdGenerator {
  int _next = 0;

  @override
  String newId() => 'id-${++_next}';
}
