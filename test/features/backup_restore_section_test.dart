import 'dart:typed_data';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/features/settings/presentation/backup_restore_section.dart';
import 'package:aularaiz/infrastructure/backup/backup_restore_gateway.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'shows Spanish backup controls and requires restore confirmation',
    (tester) async {
      final selection = _selection();
      final gateway = _FakeBackupRestoreGateway(selection: selection);

      await tester.pumpWidget(
        _host(gateway: gateway, locale: const Locale('es')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copia de seguridad y restauración'), findsOneWidget);
      expect(find.text('Crear copia de seguridad'), findsOneWidget);
      expect(find.text('Elegir copia para restaurar'), findsOneWidget);

      await tester.tap(find.text('Elegir copia para restaurar'));
      await tester.pumpAndSettle();

      expect(find.text('Copia reconocida'), findsOneWidget);
      expect(find.text('Versión de datos'), findsOneWidget);
      expect(find.text('Datos principales'), findsOneWidget);
      expect(find.text('Restaurar esta copia'), findsOneWidget);

      await tester.tap(find.text('Restaurar esta copia'));
      await tester.pumpAndSettle();

      expect(find.text('¿Preparar esta restauración?'), findsOneWidget);
      expect(gateway.stageCalls, 0);

      await tester.tap(find.text('Preparar restauración'));
      await tester.pumpAndSettle();

      expect(gateway.stageCalls, 1);
      expect(find.text('Restauración preparada'), findsOneWidget);

      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Cierra completamente AulaRaíz'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows English backup controls', (tester) async {
    final gateway = _FakeBackupRestoreGateway(selection: _selection());

    await tester.pumpWidget(
      _host(gateway: gateway, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backup and restore'), findsOneWidget);
    expect(find.text('Create backup'), findsOneWidget);
    expect(find.text('Choose backup to restore'), findsOneWidget);
  });

  testWidgets('invalid backup error is actionable and does not stage restore', (
    tester,
  ) async {
    final gateway = _FakeBackupRestoreGateway(
      selection: _selection(),
      selectionError: const BackupFormatException(
        BackupFormatProblem.invalidMagic,
        'invalid',
      ),
    );

    await tester.pumpWidget(
      _host(gateway: gateway, locale: const Locale('es')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir copia para restaurar'));
    await tester.pumpAndSettle();

    expect(
      find.text('El archivo no es una copia válida de AulaRaíz o está dañado.'),
      findsOneWidget,
    );
    expect(gateway.stageCalls, 0);
  });

  testWidgets('existing pending restore is surfaced after reopening settings', (
    tester,
  ) async {
    final gateway = _FakeBackupRestoreGateway(
      selection: _selection(),
      pendingRestore: true,
    );

    await tester.pumpWidget(
      _host(gateway: gateway, locale: const Locale('es')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Cierra completamente AulaRaíz'),
      findsOneWidget,
    );
    final createButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Crear copia de seguridad'),
    );
    expect(createButton.onPressed, isNull);
  });
}

Widget _host({required BackupRestoreGateway gateway, required Locale locale}) {
  return Provider<BackupRestoreGateway>.value(
    value: gateway,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: BackupRestoreSection(),
        ),
      ),
    ),
  );
}

BackupSelection _selection() {
  final preview = RestorePreview(
    manifest: BackupManifest(
      formatVersion: BackupManifest.currentFormatVersion,
      createdAtUtc: DateTime.utc(2026, 8, 23, 10, 15),
      schemaVersion: 1,
      storageProfile: 'production',
      protection: 'none',
      databaseSha256: 'abc',
      databaseLength: 3,
    ),
  );
  return BackupSelection(
    bytes: Uint8List.fromList(<int>[1, 2, 3]),
    preview: preview,
  );
}

final class _FakeBackupRestoreGateway implements BackupRestoreGateway {
  _FakeBackupRestoreGateway({
    required this.selection,
    this.selectionError,
    this.pendingRestore = false,
  });

  final BackupSelection selection;
  final Object? selectionError;
  final bool pendingRestore;
  int stageCalls = 0;

  @override
  Future<bool> hasPendingRestore() async => pendingRestore;

  @override
  Future<bool> exportBackup() async => true;

  @override
  Future<BackupSelection?> selectBackup() async {
    final error = selectionError;
    if (error != null) throw error;
    return selection;
  }

  @override
  Future<StagedRestore> stageRestore(BackupSelection selection) async {
    stageCalls += 1;
    return StagedRestore(requestId: 'test-request', preview: selection.preview);
  }
}
