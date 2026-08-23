import 'dart:convert';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/create_backup.dart';
import 'package:aularaiz/application/contracts/database_snapshotter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AulaRaizBackupCodec', () {
    const codec = AulaRaizBackupCodec();

    test('round-trips a versioned SQLite payload and manifest', () {
      final database = _sqliteBytes(seed: 7);
      final createdAt = DateTime.utc(2026, 8, 23, 3, 30);

      final encoded = codec.encode(
        databaseBytes: database,
        createdAtUtc: createdAt,
        schemaVersion: 4,
        storageProfile: 'production',
      );
      final inspected = codec.inspect(encoded);

      expect(inspected.manifest.formatVersion, 1);
      expect(inspected.manifest.createdAtUtc, createdAt);
      expect(inspected.manifest.schemaVersion, 4);
      expect(inspected.manifest.storageProfile, 'production');
      expect(inspected.manifest.protection, 'none');
      expect(inspected.manifest.databaseLength, database.length);
      expect(inspected.databaseBytes, orderedEquals(database));
      expect(inspected.manifest.databaseSha256, hasLength(64));
    });

    test('detects payload tampering through SHA-256', () {
      final encoded = codec.encode(
        databaseBytes: _sqliteBytes(seed: 11),
        createdAtUtc: DateTime.utc(2026, 8, 23),
        schemaVersion: 1,
        storageProfile: 'production',
      );
      encoded[encoded.length - 1] ^= 0xff;

      expect(
        () => codec.inspect(encoded),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.problem,
            'problem',
            BackupFormatProblem.checksumMismatch,
          ),
        ),
      );
    });

    test('rejects files without the AulaRaíz magic header', () {
      final invalid = Uint8List.fromList(utf8.encode('not-a-backup'));

      expect(
        () => codec.inspect(invalid),
        throwsA(
          isA<BackupFormatException>().having(
            (error) => error.problem,
            'problem',
            BackupFormatProblem.truncated,
          ),
        ),
      );
    });
  });

  test('CreateBackup snapshots once and records source metadata', () async {
    final snapshotter = _FakeSnapshotter(_sqliteBytes(seed: 19));
    final createBackup = CreateBackup(
      snapshotter: snapshotter,
      schemaVersion: 3,
      storageProfile: 'demo',
    );
    final createdAt = DateTime.utc(2026, 8, 23, 4);

    final bytes = await createBackup(createdAtUtc: createdAt);
    final inspection = const AulaRaizBackupCodec().inspect(bytes);

    expect(snapshotter.calls, 1);
    expect(inspection.manifest.createdAtUtc, createdAt);
    expect(inspection.manifest.schemaVersion, 3);
    expect(inspection.manifest.storageProfile, 'demo');
  });
}

Uint8List _sqliteBytes({required int seed}) {
  final header = ascii.encode('SQLite format 3\u0000');
  return Uint8List.fromList(<int>[
    ...header,
    ...List<int>.generate(64, (index) => (seed + index) & 0xff),
  ]);
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
