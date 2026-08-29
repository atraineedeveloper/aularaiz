import 'package:aularaiz/app/app.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('renders the Spanish first-run school setup', (tester) async {
    final settings = AppSettingsController()..setLocale(const Locale('es'));
    final setupRepository = _EmptySchoolSetupRepository();
    final groupRepository = _EmptyTeachingGroupRepository();
    final ids = _TestIdGenerator();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          Provider<SchoolSetupRepository>.value(value: setupRepository),
          Provider<TeachingGroupRepository>.value(value: groupRepository),
          Provider<CreateInitialSchoolSetup>(
            create: (_) => CreateInitialSchoolSetup(
              repository: setupRepository,
              idGenerator: ids,
            ),
          ),
          Provider<CreateTeachingGroup>(
            create: (_) => CreateTeachingGroup(
              repository: groupRepository,
              idGenerator: ids,
            ),
          ),
          Provider<CreateInitialWorkspace>(
            create: (context) => CreateInitialWorkspace(
              createSchoolSetup: context.read<CreateInitialSchoolSetup>(),
              createTeachingGroup: context.read<CreateTeachingGroup>(),
              schoolSetupRepository: setupRepository,
            ),
          ),
        ],
        child: const AulaRaizApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configura tu escuela'), findsOneWidget);
    expect(find.text('Nombre de la escuela'), findsOneWidget);
    expect(find.text('Guardar y comenzar'), findsOneWidget);
  });
}

final class _EmptyTeachingGroupRepository implements TeachingGroupRepository {
  @override
  Future<TeachingGroup?> findById(String id) async => null;

  @override
  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId) async =>
      const [];

  @override
  Future<void> save(TeachingGroup group) async {}
}

final class _EmptySchoolSetupRepository implements SchoolSetupRepository {
  @override
  Future<bool> hasInitialSetup() async => false;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async => null;

  @override
  Future<List<InitialSchoolSetup>> listSetups() async => const [];

  @override
  Future<InitialSchoolSetup?> loadForSchool(String schoolId) async => null;

  @override
  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  }) async {}
}

final class _TestIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String newId() {
    _value += 1;
    return 'test-$_value';
  }
}
