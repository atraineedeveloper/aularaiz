import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late _Ids ids;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    ids = _Ids();
    await database
        .into(database.schools)
        .insert(
          const SchoolsCompanion(
            id: Value('school-1'),
            name: Value('E1'),
            organization: Value(SchoolOrganization.complete),
          ),
        );
    await database
        .into(database.schoolYears)
        .insert(
          SchoolYearsCompanion(
            id: const Value('year-1'),
            label: const Value('2026-2027'),
            startsOn: Value(DateTime(2026, 8, 31)),
            endsOn: Value(DateTime(2027, 7, 15)),
          ),
        );
  });

  tearDown(() => database.close());

  CreateTeachingGroup useCase(TeachingGroupRepository repository) =>
      CreateTeachingGroup(repository: repository, idGenerator: ids);

  test('allows several groups per school within one school year', () async {
    final repository = DriftTeachingGroupRepository(database);
    final create = useCase(repository);

    await create(
      schoolId: 'school-1',
      schoolYearId: 'year-1',
      name: '2° A',
      grades: {PrimaryGrade.second},
      contract: TeachingContract(
        startsOn: DateTime(2026, 8, 31),
        endsOn: DateTime(2026, 12, 18),
      ),
    );
    final second = await create(
      schoolId: 'school-1',
      schoolYearId: 'year-1',
      name: '3° B',
      grades: {PrimaryGrade.third},
      contract: TeachingContract(
        startsOn: DateTime(2027, 1, 7),
        endsOn: DateTime(2027, 7, 15),
      ),
    );

    final groups = await repository.listForSchoolYear('year-1');
    expect(groups, hasLength(2));
    expect(second.contract, isNotNull);
    expect(second.contract!.startsOn, DateTime(2027, 1, 7));
  });

  test('rejects overlapping contracts in the same school year', () async {
    final repository = DriftTeachingGroupRepository(database);
    final create = useCase(repository);

    await create(
      schoolId: 'school-1',
      schoolYearId: 'year-1',
      name: '2° A',
      grades: {PrimaryGrade.second},
      contract: TeachingContract(
        startsOn: DateTime(2026, 8, 31),
        endsOn: DateTime(2026, 12, 18),
      ),
    );

    await expectLater(
      create(
        schoolId: 'school-1',
        schoolYearId: 'year-1',
        name: '3° B',
        grades: {PrimaryGrade.third},
        contract: TeachingContract(
          startsOn: DateTime(2026, 12, 1),
          endsOn: DateTime(2027, 5, 30),
        ),
      ),
      throwsStateError,
    );

    final groups = await repository.listForSchoolYear('year-1');
    expect(groups, hasLength(1));
  });
}

final class _Ids implements IdGenerator {
  int _next = 0;

  @override
  String newId() => 'id-${++_next}';
}
