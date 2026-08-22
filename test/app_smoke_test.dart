import 'package:aularaiz/app/app.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('renders the Spanish localized foundation screen', (tester) async {
    final settings = AppSettingsController()..setLocale(const Locale('es'));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const AulaRaizApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AulaRaíz'), findsOneWidget);
    expect(find.text('Tu aula, organizada'), findsOneWidget);
  });
}
