import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/backup_models.dart';
import 'package:aularaiz/infrastructure/backup/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BackupCodec codec;
  late Uint8List sqliteBytes;

  setUp(() {
    codec = BackupCodec(
      argon2Memory: 8192,
      argon2Iterations: 1,
      argon2Parallelism: 1,
      random: Random(42),
    );
    sqliteBytes = _fakeSqliteBytes();
  });

  test('unprotected backup round-trips and exposes technical metadata', () async {
    final encoded = await codec.encode(
      sqliteBytes: sqliteBytes,
      createdAt: DateTime.utc(2026, 8, 23, 3, 30),
      schemaVersion: 1,
      storageProfile: 'production',
    );

    final inspection = await codec.inspect(encoded);
    expect(inspection.formatVersion, 1);
    expect(inspection.schemaVersion, 1);
    expect(inspection.storageProfile, 'production');
    expect(inspection.protection, BackupProtection.none);
    expect(
      inspection.isCompatibleWith(
        supportedSchemaVersion: 1,
        expectedStorageProfile: 'production',
      ),
      isTrue,
    );

    final decoded = await codec.decode(encoded);
    expect(decoded.sqliteBytes, orderedEquals(sqliteBytes));
  });

  test('password backup can be inspected without revealing its payload', () async {
    final encoded = await codec.encode(
      sqliteBytes: sqliteBytes,
      createdAt: DateTime.utc(2026, 8, 23),
      schemaVersion: 1,
      storageProfile: 'production',
      password: 'correct horse battery staple',
    );

    final inspection = await codec.inspect(encoded);
    expect(inspection.protection, BackupProtection.password);
    expect(
      () => codec.decode(encoded),
      throwsA(isA<BackupPasswordRequiredException>()),
    );

    final decoded = await codec.decode(
      encoded,
      password: 'correct horse battery staple',
    );
    expect(decoded.sqliteBytes, orderedEquals(sqliteBytes));
  });

  test('wrong password fails authenticated decryption', () async {
    final encoded = await codec.encode(
      sqliteBytes: sqliteBytes,
      createdAt: DateTime.utc(2026, 8, 23),
      schemaVersion: 1,
      storageProfile: 'production',
      password: 'right-password',
    );

    expect(
      () => codec.decode(encoded, password: 'wrong-password'),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });

  test('payload corruption is rejected before restore', () async {
    final encoded = await codec.encode(
      sqliteBytes: sqliteBytes,
      createdAt: DateTime.utc(2026, 8, 23),
      schemaVersion: 1,
      storageProfile: 'production',
    );
    final document = jsonDecode(utf8.decode(encoded)) as Map<String, dynamic>;
    final payload = base64Decode(document['payload'] as String);
    payload[payload.length - 1] ^= 0xff;
    document['payload'] = base64Encode(payload);
    final corrupted = Uint8List.fromList(utf8.encode(jsonEncode(document)));

    expect(
      () => codec.inspect(corrupted),
      throwsA(isA<BackupIntegrityException>()),
    );
  });

  test('non-SQLite payloads are never accepted as backups', () async {
    expect(
      () => codec.encode(
        sqliteBytes: Uint8List.fromList(utf8.encode('not a database')),
        createdAt: DateTime.utc(2026, 8, 23),
        schemaVersion: 1,
        storageProfile: 'production',
      ),
      throwsA(isA<BackupFormatException>()),
    );
  });
}

Uint8List _fakeSqliteBytes() {
  final bytes = Uint8List(256);
  final header = <int>[
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];
  bytes.setRange(0, header.length, header);
  for (var index = header.length; index < bytes.length; index += 1) {
    bytes[index] = index % 251;
  }
  return bytes;
}
