import 'dart:convert';
import 'dart:typed_data';

import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/portable_backup_protector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PortableBackupProtector', () {
    test('encrypts a backup with a transfer code and restores it', () async {
      final protector = PortableBackupProtector(
        transferCode: 'ABCD-EFGH-JKLM-NPQR',
      );
      final clear = _clearBackupBytes();

      final protected = await protector.protect(clear);
      final restored = await protector.unprotect(protected);

      expect(protected, isNot(orderedEquals(clear)));
      expect(
        _containsSequence(protected, utf8.encode('AULARAIZ_BACKUP\n')),
        isFalse,
      );
      expect(restored, orderedEquals(clear));
    });

    test('accepts codes with lower case, spaces and dashes', () async {
      final source = PortableBackupProtector(
        transferCode: 'ABCD-EFGH-JKLM-NPQR',
      );
      final destination = PortableBackupProtector(
        transferCode: 'abcd efgh jklm npqr',
      );

      final protected = await source.protect(_clearBackupBytes());

      expect(await destination.unprotect(protected), _clearBackupBytes());
    });

    test('rejects an incorrect transfer code', () async {
      final source = PortableBackupProtector(
        transferCode: 'ABCD-EFGH-JKLM-NPQR',
      );
      final destination = PortableBackupProtector(
        transferCode: 'ZZZZ-ZZZZ-ZZZZ-ZZZZ',
      );
      final protected = await source.protect(_clearBackupBytes());

      expect(
        () => destination.unprotect(protected),
        throwsA(
          isA<BackupProtectionException>().having(
            (error) => error.problem,
            'problem',
            BackupProtectionProblem.authenticationFailed,
          ),
        ),
      );
    });

    test('generates grouped transfer codes', () {
      final code = generatePortableBackupTransferCode();

      expect(code, matches(RegExp(r'^[A-Z2-9]{4}(-[A-Z2-9]{4}){3}$')));
    });
  });
}

Uint8List _clearBackupBytes() => Uint8List.fromList(<int>[
  ...utf8.encode('AULARAIZ_BACKUP\n'),
  ...ascii.encode('SQLite format 3\u0000'),
  ...List<int>.generate(128, (index) => index & 0xff),
]);

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
