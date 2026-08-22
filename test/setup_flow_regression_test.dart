import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/home/presentation/home_screen.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'creating a school opens workspace without framework exceptions',
    (tester) async {
      final setupRepository = _MemorySchoolSetupRepository();
      final groupRepository = _MemoryTeachingGroupRepository();
      final ids = _TestIdGenerator();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
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
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeScreen(),
          ),
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

      final submit = find.text('Guardar y continuar');
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
}

final class _MemorySchoolSetupRepository implements SchoolSetupRepository {
  InitialSchoolSetup? _setup;

  @override
  Future<bool> hasInitialSetup() async => _setup != null;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async => _setup;

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
