import 'package:aularaiz/app/app.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts and exposes its product identity', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppSettingsController(),
        child: const AulaRaizApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AulaRaíz'), findsOneWidget);
  });
}
