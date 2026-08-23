import 'dart:typed_data';

enum BackupProtection { none, password }

final class BackupInspection {
  const BackupInspection({
    required this.formatVersion,
    required this.createdAt,
    required this.schemaVersion,
    required this.storageProfile,
    required this.protection,
    required this.payloadLength,
    required this.payloadSha256,
  });

  final int formatVersion;
  final DateTime createdAt;
  final int schemaVersion;
  final String storageProfile;
  final BackupProtection protection;
  final int payloadLength;
  final String payloadSha256;

  bool isCompatibleWith({
    required int supportedSchemaVersion,
    required String expectedStorageProfile,
  }) {
    return formatVersion == 1 &&
        schemaVersion == supportedSchemaVersion &&
        storageProfile == expectedStorageProfile;
  }
}

final class DecodedBackup {
  DecodedBackup({required this.inspection, required Uint8List sqliteBytes})
    : sqliteBytes = Uint8List.fromList(sqliteBytes);

  final BackupInspection inspection;
  final Uint8List sqliteBytes;
}
