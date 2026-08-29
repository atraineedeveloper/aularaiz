import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftSchoolSetupRepository repository;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftSchoolSetupRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('initial setup persists school and school year together', () async {
    final createSetup = CreateInitialSchoolSetup(
      repository: repository,
      idGenerator: _SequenceIdGenerator(),
    );

    await createSetup(
      schoolName: 'Escuela Demo',
      cct: 'DEMO000001',
      organization: SchoolOrganization.complete,
      state: 'Entidad Demo',
      municipality: 'Municipio Demo',
      locality: 'Localidad Demo',
      schoolYearLabel: '2026-2027',
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2027, 7, 15),
    );

    expect(await repository.hasInitialSetup(), isTrue);

    final school = await database.select(database.schools).getSingle();
    final schoolYear = await database.select(database.schoolYears).getSingle();

    expect(school.id, 'id-1');
    expect(school.name, 'Escuela Demo');
    expect(school.organization, SchoolOrganization.complete);
    expect(schoolYear.id, 'id-2');
    expect(schoolYear.label, '2026-2027');
  });

  test('initial setup cannot be created twice', () async {
    final createSetup = CreateInitialSchoolSetup(
      repository: repository,
      idGenerator: _SequenceIdGenerator(),
    );

    Future<void> create() => createSetup(
      schoolName: 'Escuela Demo',
      schoolYearLabel: '2026-2027',
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2027, 7, 15),
    );

    await create();

    await expectLater(create(), throwsA(isA<StateError>()));
    expect((await database.select(database.schools).get()).length, 1);
    expect((await database.select(database.schoolYears).get()).length, 1);
  });

  test(
    'editing extension delegates to editable repository without recursion',
    () async {
      await _createSetup(repository);
      final contract = repository as SchoolSetupRepository;
      final setup = (await contract.listSetups()).single;

      await contract.updateSchool(
        School(
          id: setup.school.id,
          name: 'Escuela Actualizada',
          cct: setup.school.cct,
          organization: setup.school.organization,
          state: setup.school.state,
          municipality: setup.school.municipality,
          locality: setup.school.locality,
        ),
      );

      expect(
        (await contract.listSetups()).single.school.name,
        'Escuela Actualizada',
      );
    },
  );

  test('deletion extension delegates without recursion', () async {
    await _createSetup(repository);
    final contract = repository as SchoolSetupRepository;
    final schoolId = (await contract.listSetups()).single.school.id;

    await contract.deleteSchool(schoolId);

    expect(await contract.listSetups(), isEmpty);
  });
}

Future<void> _createSetup(SchoolSetupRepository repository) {
  return CreateInitialSchoolSetup(
    repository: repository,
    idGenerator: _SequenceIdGenerator(),
  )(
    schoolName: 'Escuela Demo',
    cct: 'DEMO000001',
    schoolYearLabel: '2026-2027',
    startsOn: DateTime(2026, 8, 31),
    endsOn: DateTime(2027, 7, 15),
  );
}

final class _SequenceIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String newId() {
    _value += 1;
    return 'id-$_value';
  }
}
