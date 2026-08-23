import 'dart:convert';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/create_backup.dart';
import 'package:aularaiz/application/contracts/database_snapshotter.dart';
import 'package:aularaiz/infrastructure/backup/device_backup_protector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CreateBackup protects the complete backup before publication',
    () async {
      final keyStore = _MemoryKeyStore(_key());
      final protector = DeviceBackupProtector(keyStore: keyStore);
      final snapshotter = _FakeSnapshotter(_sqliteBytes());
      final createBackup = CreateBackup(
        snapshotter: snapshotter,
        schemaVersion: 3,
        storageProfile: 'production',
        protector: protector,
      );
      final createdAt = DateTime.utc(2026, 8, 23, 12);

      final publishedBytes = await createBackup(createdAtUtc: createdAt);
      final clearBackup = await protector.unprotect(publishedBytes);
      final inspection = const AulaRaizBackupCodec().inspect(clearBackup);

      expect(snapshotter.calls, 1);
      expect(
        _startsWith(publishedBytes, utf8.encode('AULARAIZ_PROTECTED\n')),
        isTrue,
      );
      expect(
        _startsWith(publishedBytes, utf8.encode('AULARAIZ_BACKUP\n')),
        isFalse,
      );
      expect(inspection.manifest.createdAtUtc, createdAt);
      expect(inspection.manifest.schemaVersion, 3);
      expect(inspection.manifest.storageProfile, 'production');
      expect(inspection.databaseBytes, orderedEquals(_sqliteBytes()));
    },
  );
}

Uint8List _sqliteBytes() => Uint8List.fromList(<int>[
  ...ascii.encode('SQLite format 3\u0000'),
  ...List<int>.generate(64, (index) => (73 + index) & 0xff),
]);

Uint8List _key() => Uint8List.fromList(
  List<int>.generate(
    SecureBackupEncryptionKeyStore.keyLength,
    (index) => (index * 13 + 5) & 0xff,
  ),
);

bool _startsWith(List<int> value, List<int> prefix) {
  if (value.length < prefix.length) return false;
  for (var index = 0; index < prefix.length; index += 1) {
    if (value[index] != prefix[index]) return false;
  }
  return true;
}

final class _FakeSnapshotter implements DatabaseSnapshotter {
  _FakeSnapshotter(this.bytes);

  final Uint8List bytes;
  int calls = 0;

  @override
  Future<Uint8List> createSnapshot() async {
    calls += 1;
    return Uint8List.fromList(bytes);
  }
}

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
