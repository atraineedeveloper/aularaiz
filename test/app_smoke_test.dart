import 'package:aularaiz/app/app.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('renders the localized foundation screen', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettingsController(),
        child: const AulaRaizApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AulaRaíz'), findsOneWidget);
    expect(find.text('Tu aula, organizada'), findsOneWidget);
  });
}
