import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/application/teacher/save_teacher_profile.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_teacher_profile_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/teacher/teacher_profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftTeacherProfileRepository repository;
  late _Ids ids;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftTeacherProfileRepository(database);
    ids = _Ids();
  });

  tearDown(() => database.close());

  test('teacher profile is saved and loaded back', () async {
    expect(await repository.load(), isNull);

    final saved = await SaveTeacherProfile(repository: repository)(
      fullName: '  María Pérez López  ',
    );
    expect(saved.id, TeacherProfile.localProfileId);
    expect(saved.fullName, 'María Pérez López');

    final loaded = await repository.load();
    expect(loaded, isNotNull);
    expect(loaded!.id, TeacherProfile.localProfileId);
    expect(loaded.fullName, 'María Pérez López');
  });

  test(
    'saving again updates the single local profile without duplicating',
    () async {
      final save = SaveTeacherProfile(repository: repository);
      await save(fullName: 'María Pérez López');
      await save(fullName: 'María Pérez de Sánchez');

      final rows = await database.select(database.teacherProfiles).get();
      expect(rows, hasLength(1));

      final loaded = await repository.load();
      expect(loaded!.fullName, 'María Pérez de Sánchez');
    },
  );

  test('teacher profile survives creating a new school and survives school deletion', () async {
    final schoolRepository = DriftSchoolSetupRepository(database);
    final groupRepository = DriftTeachingGroupRepository(database);
    final createWorkspace = CreateInitialWorkspace(
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

    await SaveTeacherProfile(repository: repository)(
      fullName: 'María Pérez López',
    );

    await createWorkspace(
      schoolName: 'Primaria Primera',
      organization: SchoolOrganization.unspecified,
      schoolYearLabel: '2025-2026',
      startsOn: DateTime(2025, 9, 1),
      endsOn: DateTime(2026, 7, 15),
      groupName: '1° A',
      grades: {PrimaryGrade.first},
    );

    // Creating a second school keeps the same single local profile.
    await createWorkspace(
      schoolName: 'Primaria Segunda',
      organization: SchoolOrganization.unspecified,
      schoolYearLabel: '2026-2027',
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2027, 7, 15),
      groupName: '2° A',
      grades: {PrimaryGrade.second},
    );

    expect((await schoolRepository.listSetups()), hasLength(2));
    expect((await repository.load())!.fullName, 'María Pérez López');

    // And deleting one of the schools never touches the profile row.
    final setups = await schoolRepository.listSetups();
    await schoolRepository.deleteSchool(setups.first.school.id);
    expect((await repository.load())!.fullName, 'María Pérez López');
  });
}

final class _Ids implements IdGenerator {
  int _next = 0;

  @override
  String newId() => 'id-${++_next}';
}
