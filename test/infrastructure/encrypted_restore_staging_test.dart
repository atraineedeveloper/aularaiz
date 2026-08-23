import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/device_backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/restore_staging_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'encrypted backup can be inspected and staged with installation key',
    () async {
      final supportDirectory = await Directory.systemTemp.createTemp(
        'aularaiz-encrypted-restore-test-',
      );
      addTearDown(() async {
        if (await supportDirectory.exists()) {
          await supportDirectory.delete(recursive: true);
        }
      });

      final keyStore = _MemoryKeyStore(_key());
      final protector = DeviceBackupProtector(keyStore: keyStore);
      final databaseBytes = await _createDatabaseBytes(supportDirectory);
      final clearBackup = const AulaRaizBackupCodec().encode(
        databaseBytes: databaseBytes,
        createdAtUtc: DateTime.utc(2026, 8, 23, 12, 30),
        schemaVersion: 1,
        storageProfile: StorageProfile.production.name,
      );
      final encryptedBackup = await protector.protect(clearBackup);
      final service = RestoreStagingService(
        profile: StorageProfile.production,
        currentSchemaVersion: 1,
        directoryProvider: () async => supportDirectory,
        protector: protector,
      );

      final preview = await service.inspect(encryptedBackup);
      final staged = await service.stage(encryptedBackup);

      expect(preview.manifest.storageProfile, 'production');
      expect(preview.manifest.schemaVersion, 1);
      expect(
        staged.preview.manifest.createdAtUtc,
        DateTime.utc(2026, 8, 23, 12, 30),
      );
    },
  );
}

Future<Uint8List> _createDatabaseBytes(Directory directory) async {
  final file = File(
    '${directory.path}${Platform.pathSeparator}candidate.sqlite',
  );
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
  } finally {
    database.close();
  }
  return file.readAsBytes();
}

Uint8List _key() => Uint8List.fromList(
  List<int>.generate(
    SecureBackupEncryptionKeyStore.keyLength,
    (index) => (index * 19 + 3) & 0xff,
  ),
);

final class _MemoryKeyStore implements BackupEncryptionKeyStore {
  _MemoryKeyStore(this._key);

  Uint8List? _key;

  @override
  Future<Uint8List?> readKey() async =>
      _key == null ? null : Uint8List.fromList(_key!);

  @override
  Future<void> writeKey(Uint8List keyBytes) async {
    _key = Uint8List.fromList(keyBytes);
  }
}
