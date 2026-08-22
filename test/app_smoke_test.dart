import 'package:aularaiz/app/app.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('renders the Spanish first-run school setup', (tester) async {
    final settings = AppSettingsController()..setLocale(const Locale('es'));
    final setupRepository = _EmptySchoolSetupRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
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

    expect(find.text('Configura tu escuela'), findsOneWidget);
    expect(find.text('Nombre de la escuela'), findsOneWidget);
    expect(find.text('Guardar y continuar'), findsOneWidget);
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
  int _value = 0;

  @override
  String newId() {
    _value += 1;
    return 'test-$_value';
  }
}
