import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/data/local/storage_layout.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/restore_bootstrap_service.dart';
import 'package:aularaiz/infrastructure/backup/restore_request_marker.dart';
import 'package:aularaiz/infrastructure/backup/restore_staging_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('restore staging and bootstrap', () {
    late Directory supportDirectory;
    late AulaRaizStorageLayout layout;

    setUp(() async {
      supportDirectory = await Directory.systemTemp.createTemp(
        'aularaiz-restore-test-',
      );
      layout = await AulaRaizStorageLayout.resolve(
        StorageProfile.production,
        directoryProvider: () async => supportDirectory,
      );
    });

    tearDown(() async {
      if (await supportDirectory.exists()) {
        await supportDirectory.delete(recursive: true);
      }
    });

    test(
      'staging validates candidate but does not snapshot current data',
      () async {
        final candidateBytes = await _createDatabaseBytes(
          supportDirectory,
          'candidate-source',
          'candidate',
        );
        final backup = _encodeBackup(candidateBytes);
        final service = RestoreStagingService(
          profile: StorageProfile.production,
          currentSchemaVersion: 1,
          directoryProvider: () async => supportDirectory,
        );

        final staged = await service.stage(backup);
        final marker = RestoreRequestMarker.decode(
          await layout.restoreMarkerFile.readAsString(),
        );

        expect(marker.state, RestoreRequestState.staged);
        expect(marker.safetySha256, isNull);
        expect(
          await layout.pendingRestoreFile(staged.requestId).exists(),
          isTrue,
        );
        expect(
          await layout.safetyRestoreFile(staged.requestId).exists(),
          isFalse,
        );
      },
    );

    test('applies staged database and removes recovery artifacts', () async {
      await _writeActiveDatabase(layout.databaseFile, 'current');
      final candidateBytes = await _createDatabaseBytes(
        supportDirectory,
        'candidate-source',
        'candidate',
      );
      final staged = await RestoreStagingService(
        profile: StorageProfile.production,
        currentSchemaVersion: 1,
        directoryProvider: () async => supportDirectory,
      ).stage(_encodeBackup(candidateBytes));
      var snapshotCalls = 0;

      final outcome = await RestoreBootstrapService(
        profile: StorageProfile.production,
        currentSchemaVersion: 1,
        currentSnapshotProvider: () async {
          snapshotCalls += 1;
          return layout.databaseFile.readAsBytes();
        },
        restoredDatabaseOpener: (_) async {},
        directoryProvider: () async => supportDirectory,
      ).applyPending();

      expect(outcome, RestoreBootstrapOutcome.applied);
      expect(snapshotCalls, 1);
      expect(_readMarker(layout.databaseFile), 'candidate');
      expect(await layout.restoreMarkerFile.exists(), isFalse);
      expect(
        await layout.pendingRestoreFile(staged.requestId).exists(),
        isFalse,
      );
      expect(
        supportDirectory.listSync().where(layout.isManagedRestoreArtifact),
        isEmpty,
      );
    });

    test('rollback preserves changes made after staging', () async {
      await _writeActiveDatabase(layout.databaseFile, 'current');
      final candidateBytes = await _createDatabaseBytes(
        supportDirectory,
        'candidate-source',
        'candidate',
      );
      await RestoreStagingService(
        profile: StorageProfile.production,
        currentSchemaVersion: 1,
        directoryProvider: () async => supportDirectory,
      ).stage(_encodeBackup(candidateBytes));
      _updateMarker(layout.databaseFile, 'latest-after-stage');
      var openCalls = 0;

      final outcome = await RestoreBootstrapService(
        profile: StorageProfile.production,
        currentSchemaVersion: 1,
        currentSnapshotProvider: () => layout.databaseFile.readAsBytes(),
        restoredDatabaseOpener: (_) async {
          openCalls += 1;
          if (openCalls == 1) throw StateError('candidate rejected');
        },
        directoryProvider: () async => supportDirectory,
      ).applyPending();

      expect(outcome, RestoreBootstrapOutcome.rolledBack);
      expect(openCalls, 2);
      expect(_readMarker(layout.databaseFile), 'latest-after-stage');
      expect(await layout.restoreMarkerFile.exists(), isFalse);
    });

    test('applying marker rolls back after an interrupted replace', () async {
      await _writeActiveDatabase(layout.databaseFile, 'original');
      final originalBytes = await layout.databaseFile.readAsBytes();
      final candidateBytes = await _createDatabaseBytes(
        supportDirectory,
        'candidate-source',
        'candidate',
      );
      final staged = await RestoreStagingService(
        profile: StorageProfile.production,
        currentSchemaVersion: 1,
        directoryProvider: () async => supportDirectory,
      ).stage(_encodeBackup(candidateBytes));
      final stagedMarker = RestoreRequestMarker.decode(
        await layout.restoreMarkerFile.readAsString(),
      );
      final safety = layout.safetyRestoreFile(staged.requestId);
      await safety.writeAsBytes(originalBytes, flush: true);
      final applyingMarker = stagedMarker.copyWith(
        state: RestoreRequestState.applying,
        safetySha256: sha256.convert(originalBytes).toString(),
      );
      await layout.restoreMarkerFile.writeAsString(
        applyingMarker.encode(),
        flush: true,
      );
      await layout.databaseFile.writeAsBytes(candidateBytes, flush: true);

      final outcome = await RestoreBootstrapService(
        profile: StorageProfile.production,
        currentSchemaVersion: 1,
        currentSnapshotProvider: () async {
          throw StateError('must not snapshot an applying database');
        },
        restoredDatabaseOpener: (_) async {},
        directoryProvider: () async => supportDirectory,
      ).applyPending();

      expect(outcome, RestoreBootstrapOutcome.rolledBack);
      expect(_readMarker(layout.databaseFile), 'original');
      expect(await layout.restoreMarkerFile.exists(), isFalse);
    });
  });
}

Uint8List _encodeBackup(Uint8List databaseBytes) {
  return const AulaRaizBackupCodec().encode(
    databaseBytes: databaseBytes,
    createdAtUtc: DateTime.utc(2026, 8, 23, 4),
    schemaVersion: 1,
    storageProfile: StorageProfile.production.name,
  );
}

Future<void> _writeActiveDatabase(File file, String marker) async {
  final bytes = await _createDatabaseBytes(
    file.parent,
    'active-source-${DateTime.now().microsecondsSinceEpoch}',
    marker,
  );
  await file.writeAsBytes(bytes, flush: true);
}

Future<Uint8List> _createDatabaseBytes(
  Directory directory,
  String name,
  String marker,
) async {
  final file = File('${directory.path}${Platform.pathSeparator}$name.sqlite');
  if (await file.exists()) await file.delete();
  final database = sqlite3.open(file.path);
  try {
    database.execute('PRAGMA user_version = 1');
    for (final table in <String>[
      'schools',
      'school_years',
      'teaching_groups',
      'students',
      'enrollments',
    ]) {
      database.execute('CREATE TABLE $table (id TEXT PRIMARY KEY)');
    }
    database.execute('CREATE TABLE restore_marker (value TEXT NOT NULL)');
    final statement = database.prepare(
      'INSERT INTO restore_marker (value) VALUES (?)',
    );
    try {
      statement.execute(<Object?>[marker]);
    } finally {
      statement.close();
    }
  } finally {
    database.close();
  }
  return file.readAsBytes();
}

String _readMarker(File file) {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return database.select('SELECT value FROM restore_marker').single['value']
        as String;
  } finally {
    database.close();
  }
}

void _updateMarker(File file, String value) {
  final database = sqlite3.open(file.path);
  try {
    final statement = database.prepare('UPDATE restore_marker SET value = ?');
    try {
      statement.execute(<Object?>[value]);
    } finally {
      statement.close();
    }
  } finally {
    database.close();
  }
}
