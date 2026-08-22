import 'package:aularaiz/app/app.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts at the first-run setup when no school exists', (
    tester,
  ) async {
    final setupRepository = _EmptySchoolSetupRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) =>
                AppSettingsController()..setLocale(const Locale('es')),
          ),
          Provider<SchoolSetupRepository>.value(value: setupRepository),
          Provider<CreateInitialSchoolSetup>(
            create: (_) => CreateInitialSchoolSetup(
              repository: setupRepository,
              idGenerator: _TestIdGenerator(),
            ),
          ),
        ],
        child: const AulaRaizApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AulaRaíz'), findsOneWidget);
    expect(find.text('Configura tu escuela'), findsOneWidget);
  });
}

final class _EmptySchoolSetupRepository implements SchoolSetupRepository {
  @override
  Future<bool> hasInitialSetup() async => false;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async => null;

  @override
  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  }) async {}
}

final class _TestIdGenerator implements IdGenerator {
  @override
  String newId() => 'integration-test-id';
}
