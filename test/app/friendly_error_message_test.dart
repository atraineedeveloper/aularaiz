import 'package:aularaiz/app/errors/friendly_error_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'translates common local database failures without leaking details',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        friendlyErrorMessage(
          context,
          Exception('database is locked'),
          fallback: 'fallback',
        ),
        contains('local database is busy'),
      );
      expect(
        friendlyErrorMessage(
          context,
          Exception('UNIQUE constraint failed: schools.cct'),
          fallback: 'fallback',
        ),
        contains('value is already being used'),
      );
      expect(
        friendlyErrorMessage(
          context,
          Exception('private technical detail'),
          fallback: 'fallback',
        ),
        'fallback',
      );
    },
  );
}
