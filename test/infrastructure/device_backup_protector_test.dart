import 'dart:convert';
import 'dart:typed_data';

import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/device_backup_protector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceBackupProtector', () {
    test(
      'AES-256-GCM hides the complete inner backup and round-trips it',
      () async {
        final keyStore = _MemoryKeyStore(_key(seed: 7));
        final protector = DeviceBackupProtector(keyStore: keyStore);
        final clear = _clearBackupBytes();

        final protected = await protector.protect(clear);
        final restored = await protector.unprotect(protected);

        expect(protected, isNot(orderedEquals(clear)));
        expect(
          _containsSequence(protected, ascii.encode('SQLite format 3\u0000')),
          isFalse,
        );
        expect(
          _containsSequence(protected, utf8.encode('AULARAIZ_BACKUP\n')),
          isFalse,
        );
        expect(restored, orderedEquals(clear));
      },
    );

    test('same backup encrypted twice uses different nonces', () async {
      final keyStore = _MemoryKeyStore(_key(seed: 11));
      final protector = DeviceBackupProtector(keyStore: keyStore);
      final clear = _clearBackupBytes();

      final first = await protector.protect(clear);
      final second = await protector.protect(clear);

      expect(first, isNot(orderedEquals(second)));
      expect(await protector.unprotect(first), orderedEquals(clear));
      expect(await protector.unprotect(second), orderedEquals(clear));
    });

    test('legacy unencrypted backups remain readable', () async {
      final protector = DeviceBackupProtector(
        keyStore: _MemoryKeyStore(_key(seed: 17)),
      );
      final clear = _clearBackupBytes();

      final result = await protector.unprotect(clear);

      expect(result, orderedEquals(clear));
    });

    test(
      'backup from another installation is rejected before decryption',
      () async {
        final source = DeviceBackupProtector(
          keyStore: _MemoryKeyStore(_key(seed: 23)),
        );
        final destination = DeviceBackupProtector(
          keyStore: _MemoryKeyStore(_key(seed: 91)),
        );
        final protected = await source.protect(_clearBackupBytes());

        expect(
          () => destination.unprotect(protected),
          throwsA(
            isA<BackupProtectionException>().having(
              (error) => error.problem,
              'problem',
              BackupProtectionProblem.keyMismatch,
            ),
          ),
        );
      },
    );

    test('ciphertext tampering is rejected by GCM authentication', () async {
      final protector = DeviceBackupProtector(
        keyStore: _MemoryKeyStore(_key(seed: 31)),
      );
      final protected = await protector.protect(_clearBackupBytes());
      protected[protected.length - 1] ^= 0xff;

      expect(
        () => protector.unprotect(protected),
        throwsA(
          isA<BackupProtectionException>().having(
            (error) => error.problem,
            'problem',
            BackupProtectionProblem.authenticationFailed,
          ),
        ),
      );
    });

    test('missing installation key is reported explicitly', () async {
      final source = DeviceBackupProtector(
        keyStore: _MemoryKeyStore(_key(seed: 47)),
      );
      final protected = await source.protect(_clearBackupBytes());
      final destination = DeviceBackupProtector(
        keyStore: _MemoryKeyStore(null),
      );

      expect(
        () => destination.unprotect(protected),
        throwsA(
          isA<BackupProtectionException>().having(
            (error) => error.problem,
            'problem',
            BackupProtectionProblem.keyUnavailable,
          ),
        ),
      );
    });
  });
}

Uint8List _clearBackupBytes() => Uint8List.fromList(<int>[
  ...utf8.encode('AULARAIZ_BACKUP\n'),
  ...ascii.encode('SQLite format 3\u0000'),
  ...List<int>.generate(128, (index) => index & 0xff),
]);

Uint8List _key({required int seed}) => Uint8List.fromList(
  List<int>.generate(
    SecureBackupEncryptionKeyStore.keyLength,
    (index) => (seed + index * 17) & 0xff,
  ),
);

bool _containsSequence(List<int> value, List<int> sequence) {
  if (sequence.isEmpty) return true;
  if (value.length < sequence.length) return false;
  for (var start = 0; start <= value.length - sequence.length; start += 1) {
    var matches = true;
    for (var index = 0; index < sequence.length; index += 1) {
      if (value[start + index] != sequence[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

final class _MemoryKeyStore implements BackupEncryptionKeyStore {
  _MemoryKeyStore(Uint8List? key) : _key = key;

  Uint8List? _key;

  @override
  Future<Uint8List?> readKey() async =>
      _key == null ? null : Uint8List.fromList(_key!);

  @override
  Future<void> writeKey(Uint8List keyBytes) async {
    _key = Uint8List.fromList(keyBytes);
  }
}
