import 'dart:io';

import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/infrastructure/backup/drift_database_snapshotter.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('VACUUM INTO snapshot can be reopened and preserves data', () async {
    final tempDirectory = await Directory.systemTemp.createTemp(
      'aularaiz-backup-test-',
    );
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();
    await database.customStatement(
      'CREATE TABLE backup_marker (value TEXT NOT NULL)',
    );
    await database.customStatement(
      'INSERT INTO backup_marker (value) VALUES (?)',
      <Object?>['preserved'],
    );

    final snapshotter = DriftDatabaseSnapshotter(
      database: database,
      tempDirectoryProvider: () async => tempDirectory,
    );
    final snapshotBytes = await snapshotter.createSnapshot();

    expect(snapshotBytes, isNotEmpty);
    expect(
      String.fromCharCodes(snapshotBytes.take(16)),
      'SQLite format 3\u0000',
    );
    expect(tempDirectory.listSync(), isEmpty);

    final restoredFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}restored.sqlite',
    );
    await restoredFile.writeAsBytes(snapshotBytes, flush: true);
    final restored = AppDatabase.forTesting(NativeDatabase(restoredFile));
    addTearDown(restored.close);

    final rows = await restored
        .customSelect('SELECT value FROM backup_marker')
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.read<String>('value'), 'preserved');
  });
}
