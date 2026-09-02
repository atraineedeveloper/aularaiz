import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teacher_profile_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/application/teacher/save_teacher_profile.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_leadership_role.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/teacher/teacher_profile.dart';
import 'package:aularaiz/domain/teacher/teaching_role.dart';
import 'package:aularaiz/features/home/presentation/home_screen.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'creating a school returns to school selection without framework exceptions',
    (tester) async {
      final setupRepository = _MemorySchoolSetupRepository();
      final groupRepository = _MemoryTeachingGroupRepository();
      final ids = _TestIdGenerator();

      await tester.pumpWidget(
        _testApp(
          setupRepository: setupRepository,
          groupRepository: groupRepository,
          ids: ids,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la escuela'),
        'Primaria de prueba',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'CCT (opcional)'),
        '27DPR1064V',
      );
      await tester.pump();

      final municipality = find.byKey(const ValueKey('municipality-27-none'));
      expect(municipality, findsOneWidget);
      await tester.tap(municipality);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Balancán').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del grupo'),
        '1° A',
      );
      final firstGrade = find.text('1°').last;
      await tester.ensureVisible(firstGrade);
      await tester.pumpAndSettle();
      await tester.tap(firstGrade);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo del docente'),
        'María Pérez López',
      );
      await tester.pump();

      final submit = find.text('Guardar y comenzar');
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Primaria de prueba'), findsOneWidget);
      expect(find.text('Configura tu escuela'), findsNothing);
    },
  );

  testWidgets('school setup supports 200 percent text on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final setupRepository = _MemorySchoolSetupRepository();
    final groupRepository = _MemoryTeachingGroupRepository();
    final ids = _TestIdGenerator();

    await tester.pumpWidget(
      _testApp(
        setupRepository: setupRepository,
        groupRepository: groupRepository,
        ids: ids,
        textScaler: TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Configura tu escuela'), findsOneWidget);

    final submit = find.text('Guardar y comenzar');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    expect(submit, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('school setup captures contract dates for the group', (
    tester,
  ) async {
    final setupRepository = _MemorySchoolSetupRepository();
    final groupRepository = _MemoryTeachingGroupRepository();
    final ids = _TestIdGenerator();

    await tester.pumpWidget(
      _testApp(
        setupRepository: setupRepository,
        groupRepository: groupRepository,
        ids: ids,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la escuela'),
      'Primaria de prueba',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'CCT (opcional)'),
      '27DPR1064V',
    );
    await tester.pump();

    final municipality = find.byKey(const ValueKey('municipality-27-none'));
    expect(municipality, findsOneWidget);
    await tester.tap(municipality);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balancán').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre del grupo'),
      '1° A',
    );
    final firstGrade = find.text('1°').last;
    await tester.ensureVisible(firstGrade);
    await tester.pumpAndSettle();
    await tester.tap(firstGrade);
    await tester.pumpAndSettle();

    final contractStart = find.textContaining('Inicio de contratación');
    await tester.ensureVisible(contractStart);
    await tester.pumpAndSettle();
    await tester.tap(contractStart);
    await tester.pumpAndSettle();
    await _confirmDatePicker(tester);

    final contractEnd = find.textContaining('Fin de contratación');
    await tester.ensureVisible(contractEnd);
    await tester.pumpAndSettle();
    await tester.tap(contractEnd);
    await tester.pumpAndSettle();
    await _confirmDatePicker(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo del docente'),
      'María Pérez López',
    );
    await tester.pump();

    final submit = find.text('Guardar y comenzar');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();

    final groups = groupRepository.groups;
    expect(groups, hasLength(1));
    expect(groups.single.contract, isNotNull);
    expect(groups.single.contract!.startsOn, isNotNull);
    expect(groups.single.contract!.endsOn, groups.single.contract!.startsOn);
  });

  testWidgets(
    'selecting a leadership teaching role prefills the school leadership',
    (tester) async {
      final setupRepository = _MemorySchoolSetupRepository();
      final groupRepository = _MemoryTeachingGroupRepository();
      final profileRepository = _MemoryTeacherProfileRepository();
      final ids = _TestIdGenerator();

      await tester.pumpWidget(
        _testApp(
          setupRepository: setupRepository,
          groupRepository: groupRepository,
          profileRepository: profileRepository,
          ids: ids,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo del docente'),
        'María Pérez López',
      );
      await tester.pump();

      final teachingRoleField = find
          .widgetWithText(
            DropdownButtonFormField<TeachingRole>,
            'Función del docente',
          )
          .last;
      await tester.ensureVisible(teachingRoleField);
      await tester.pumpAndSettle();
      await tester.tap(teachingRoleField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Docente con funciones de dirección').last);
      await tester.pumpAndSettle();

      final leadershipNameField = find.widgetWithText(
        TextFormField,
        'Responsable de dirección (opcional)',
      );
      final controller = tester
          .widget<TextFormField>(leadershipNameField)
          .controller;
      expect(controller?.text, 'María Pérez López');

      final leadershipRoleField = find
          .widgetWithText(
            DropdownButtonFormField<SchoolLeadershipRole?>,
            'Función de dirección',
          )
          .last;
      final selected = tester
          .widget<DropdownButtonFormField<SchoolLeadershipRole?>>(
            leadershipRoleField,
          )
          .initialValue;
      expect(selected, SchoolLeadershipRole.teacherWithLeadership);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'group-only teachers leave the school leadership fields optional',
    (tester) async {
      final setupRepository = _MemorySchoolSetupRepository();
      final groupRepository = _MemoryTeachingGroupRepository();
      final profileRepository = _MemoryTeacherProfileRepository();
      final ids = _TestIdGenerator();

      await tester.pumpWidget(
        _testApp(
          setupRepository: setupRepository,
          groupRepository: groupRepository,
          profileRepository: profileRepository,
          ids: ids,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo del docente'),
        'María Pérez López',
      );
      await tester.pump();

      // The default role is "Docente frente a grupo": the leadership name
      // stays empty and the leadership role stays unspecified.
      final leadershipNameField = find.widgetWithText(
        TextFormField,
        'Responsable de dirección (opcional)',
      );
      final controller = tester
          .widget<TextFormField>(leadershipNameField)
          .controller;
      expect(controller?.text, isEmpty);

      final leadershipRoleField = find
          .widgetWithText(
            DropdownButtonFormField<SchoolLeadershipRole?>,
            'Función de dirección',
          )
          .last;
      final selected = tester
          .widget<DropdownButtonFormField<SchoolLeadershipRole?>>(
            leadershipRoleField,
          )
          .initialValue;
      expect(selected, isNull);

      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _confirmDatePicker(WidgetTester tester) async {
  final dialog = find.byType(DatePickerDialog);
  expect(dialog, findsOneWidget);
  final confirm = find
      .descendant(of: dialog, matching: find.byType(TextButton))
      .last;
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

Widget _testApp({
  required _MemorySchoolSetupRepository setupRepository,
  required _MemoryTeachingGroupRepository groupRepository,
  _MemoryTeacherProfileRepository? profileRepository,
  required _TestIdGenerator ids,
  TextScaler? textScaler,
}) {
  final teacherProfiles =
      profileRepository ?? _MemoryTeacherProfileRepository();
  return MultiProvider(
    providers: [
      Provider<SchoolSetupRepository>.value(value: setupRepository),
      Provider<TeachingGroupRepository>.value(value: groupRepository),
      Provider<TeacherProfileRepository>.value(value: teacherProfiles),
      Provider<SaveTeacherProfile>(
        create: (_) => SaveTeacherProfile(repository: teacherProfiles),
      ),
      Provider<CreateInitialSchoolSetup>(
        create: (_) => CreateInitialSchoolSetup(
          repository: setupRepository,
          idGenerator: ids,
        ),
      ),
      Provider<CreateTeachingGroup>(
        create: (_) =>
            CreateTeachingGroup(repository: groupRepository, idGenerator: ids),
      ),
      Provider<CreateInitialWorkspace>(
        create: (context) => CreateInitialWorkspace(
          createSchoolSetup: context.read<CreateInitialSchoolSetup>(),
          createTeachingGroup: context.read<CreateTeachingGroup>(),
          schoolSetupRepository: setupRepository,
        ),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: textScaler == null
          ? null
          : (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            ),
      home: const HomeScreen(),
    ),
  );
}

final class _MemoryTeacherProfileRepository
    implements TeacherProfileRepository {
  TeacherProfile? _profile;

  @override
  Future<TeacherProfile?> load() async => _profile;

  @override
  Future<void> save(TeacherProfile profile) async {
    _profile = profile;
  }
}

final class _MemorySchoolSetupRepository implements SchoolSetupRepository {
  InitialSchoolSetup? _setup;

  @override
  Future<bool> hasInitialSetup() async => _setup != null;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async => _setup;

  @override
  Future<List<InitialSchoolSetup>> listSetups() async =>
      _setup == null ? const [] : [_setup!];

  @override
  Future<InitialSchoolSetup?> loadForSchool(String schoolId) async {
    final setup = _setup;
    return setup != null && setup.school.id == schoolId ? setup : null;
  }

  @override
  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  }) async {
    _setup = (school: school, schoolYear: schoolYear);
  }
}

final class _MemoryTeachingGroupRepository implements TeachingGroupRepository {
  final List<TeachingGroup> _groups = [];

  List<TeachingGroup> get groups => List<TeachingGroup>.unmodifiable(_groups);

  @override
  Future<TeachingGroup?> findById(String id) async {
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  @override
  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId) async {
    return _groups
        .where((group) => group.schoolYearId == schoolYearId)
        .toList(growable: false);
  }

  @override
  Future<void> save(TeachingGroup group) async {
    _groups.add(group);
  }
}

final class _TestIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String newId() {
    _next += 1;
    return 'test-$_next';
  }
}
