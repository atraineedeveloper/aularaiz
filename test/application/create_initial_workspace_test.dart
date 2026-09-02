import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_leadership_role.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/teacher/teaching_role.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftSchoolSetupRepository schoolRepository;
  late _Ids ids;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    schoolRepository = DriftSchoolSetupRepository(database);
    ids = _Ids();
  });

  tearDown(() => database.close());

  CreateInitialWorkspace useCase(TeachingGroupRepository groupRepository) {
    return CreateInitialWorkspace(
      createSchoolSetup: CreateInitialSchoolSetup(
        repository: schoolRepository,
        idGenerator: ids,
      ),
      createTeachingGroup: CreateTeachingGroup(
        repository: groupRepository,
        idGenerator: ids,
      ),
      schoolSetupRepository: schoolRepository,
    );
  }

  test('creates school, year and group as one onboarding result', () async {
    final groupRepository = DriftTeachingGroupRepository(database);
    final create = useCase(groupRepository);

    await create(
      schoolName: 'Primaria Demo',
      organization: SchoolOrganization.unspecified,
      schoolYearLabel: '2026-2027',
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2027, 7, 15),
      groupName: '1° A',
      grades: {PrimaryGrade.first},
      shift: 'Matutino',
      contract: TeachingContract(
        startsOn: DateTime(2026, 9, 1),
        endsOn: DateTime(2026, 12, 15),
      ),
    );

    final setup = (await schoolRepository.listSetups()).single;
    final groups = await groupRepository.listForSchoolYear(setup.schoolYear.id);
    expect(groups.single.name, '1° A');
    expect(groups.single.shift, 'Matutino');
    expect(groups.single.contract, isNotNull);
    expect(groups.single.contract!.startsOn, DateTime(2026, 9, 1));
    expect(groups.single.contract!.endsOn, DateTime(2026, 12, 15));
  });

  test('rolls back only the new school when group creation fails', () async {
    await useCase(DriftTeachingGroupRepository(database))(
      schoolName: 'Primaria Anterior',
      organization: SchoolOrganization.unspecified,
      schoolYearLabel: '2025-2026',
      startsOn: DateTime(2025, 9),
      endsOn: DateTime(2026, 7, 15),
      groupName: '2° A',
      grades: {PrimaryGrade.second},
    );
    final create = useCase(_FailingGroupRepository());

    await expectLater(
      create(
        schoolName: 'Primaria Nueva',
        organization: SchoolOrganization.unspecified,
        schoolYearLabel: '2026-2027',
        startsOn: DateTime(2026, 8, 31),
        endsOn: DateTime(2027, 7, 15),
        groupName: '1° A',
        grades: {PrimaryGrade.first},
      ),
      throwsStateError,
    );

    final remaining = await schoolRepository.listSetups();
    expect(remaining, hasLength(1));
    expect(remaining.single.school.name, 'Primaria Anterior');
  });

  test(
    'a school persists zone, sector, supervisor and leadership authorities',
    () async {
      final groupRepository = DriftTeachingGroupRepository(database);
      final create = useCase(groupRepository);

      await create(
        schoolName: 'Primaria con Autoridades',
        organization: SchoolOrganization.complete,
        schoolZone: 'Zona 045',
        schoolSector: 'Sector 12',
        supervisorName: 'Jorge Villalobos',
        leadershipName: 'María Pérez López',
        leadershipRole: SchoolLeadershipRole.teacherWithLeadership,
        schoolYearLabel: '2026-2027',
        startsOn: DateTime(2026, 8, 31),
        endsOn: DateTime(2027, 7, 15),
        groupName: '3° A',
        grades: {PrimaryGrade.third},
        teachingRole: TeachingRole.teacherWithLeadership,
      );

      final setup = (await schoolRepository.listSetups()).single;
      expect(setup.school.schoolZone, 'Zona 045');
      expect(setup.school.schoolSector, 'Sector 12');
      expect(setup.school.supervisorName, 'Jorge Villalobos');
      expect(setup.school.leadershipName, 'María Pérez López');
      expect(
        setup.school.leadershipRole,
        SchoolLeadershipRole.teacherWithLeadership,
      );

      final group = (await groupRepository.listForSchoolYear(
        setup.schoolYear.id,
      )).single;
      expect(group.teachingRole, TeachingRole.teacherWithLeadership);
    },
  );

  test(
    'a previous school with authorities stays intact when a new school fails',
    () async {
      await useCase(DriftTeachingGroupRepository(database))(
        schoolName: 'Primaria Anterior',
        organization: SchoolOrganization.complete,
        schoolZone: 'Zona 045',
        schoolSector: 'Sector 12',
        supervisorName: 'Jorge Villalobos',
        leadershipName: 'María Pérez López',
        leadershipRole: SchoolLeadershipRole.teacherWithLeadership,
        schoolYearLabel: '2025-2026',
        startsOn: DateTime(2025, 9),
        endsOn: DateTime(2026, 7, 15),
        groupName: '2° A',
        grades: {PrimaryGrade.second},
        teachingRole: TeachingRole.teacherWithLeadership,
      );

      final create = useCase(_FailingGroupRepository());
      await expectLater(
        create(
          schoolName: 'Primaria Nueva',
          organization: SchoolOrganization.unspecified,
          schoolYearLabel: '2026-2027',
          startsOn: DateTime(2026, 8, 31),
          endsOn: DateTime(2027, 7, 15),
          groupName: '1° A',
          grades: {PrimaryGrade.first},
        ),
        throwsStateError,
      );

      final remaining = await schoolRepository.listSetups();
      expect(remaining, hasLength(1));
      final school = remaining.single.school;
      expect(school.name, 'Primaria Anterior');
      expect(school.schoolZone, 'Zona 045');
      expect(school.schoolSector, 'Sector 12');
      expect(school.supervisorName, 'Jorge Villalobos');
      expect(school.leadershipName, 'María Pérez López');
      expect(school.leadershipRole, SchoolLeadershipRole.teacherWithLeadership);
    },
  );
}

final class _FailingGroupRepository implements TeachingGroupRepository {
  @override
  Future<TeachingGroup?> findById(String id) async => null;

  @override
  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId) async =>
      const [];

  @override
  Future<void> save(TeachingGroup group) =>
      throw StateError('Simulated group failure.');
}

final class _Ids implements IdGenerator {
  int _next = 0;

  @override
  String newId() => 'id-${++_next}';
}
