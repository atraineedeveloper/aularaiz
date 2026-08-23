import 'package:aularaiz/infrastructure/backup/backup_restore_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup filename is generic and filesystem safe', () {
    final name = buildAulaRaizBackupFileName(
      DateTime.utc(2026, 8, 23, 10, 31, 42),
    );

    expect(name, 'aularaiz-backup-20260823-103142.aularaiz');
    expect(name, isNot(contains(':')));
    expect(name, isNot(contains(' ')));
  });
}
