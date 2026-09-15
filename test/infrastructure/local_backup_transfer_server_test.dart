import 'package:aularaiz/infrastructure/backup/local_backup_transfer_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'portable transfer QR payload carries download URL and transfer code',
    () {
      final payload = buildPortableBackupTransferQrPayload(
        downloadUrl: 'http://192.168.1.10:1234/aularaiz-transfer?token=test',
        uploadUrl: 'http://192.168.1.10:1234/aularaiz-transfer-sync?token=test',
        transferCode: 'ABCD-EFGH-JKLM-NPQR',
        sourceDeviceId: 'device-1',
        sourceDeviceName: 'PC Otilio',
      );

      final parsed = parsePortableBackupTransferQrPayload(payload);

      expect(parsed, isNotNull);
      expect(
        parsed!.downloadUrl,
        'http://192.168.1.10:1234/aularaiz-transfer?token=test',
      );
      expect(
        parsed.uploadUrl,
        'http://192.168.1.10:1234/aularaiz-transfer-sync?token=test',
      );
      expect(parsed.transferCode, 'ABCD-EFGH-JKLM-NPQR');
      expect(parsed.sourceDeviceId, 'device-1');
      expect(parsed.sourceDeviceName, 'PC Otilio');
    },
  );
}
