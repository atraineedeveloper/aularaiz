import 'dart:typed_data';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/application/contracts/database_snapshotter.dart';

final class CreateBackup {
  const CreateBackup({
    required DatabaseSnapshotter snapshotter,
    required int schemaVersion,
    required String storageProfile,
    AulaRaizBackupCodec codec = const AulaRaizBackupCodec(),
    BackupProtector protector = const PassThroughBackupProtector(),
  }) : _snapshotter = snapshotter,
       _schemaVersion = schemaVersion,
       _storageProfile = storageProfile,
       _codec = codec,
       _protector = protector;

  final DatabaseSnapshotter _snapshotter;
  final int _schemaVersion;
  final String _storageProfile;
  final AulaRaizBackupCodec _codec;
  final BackupProtector _protector;

  Future<Uint8List> call({DateTime? createdAtUtc}) async {
    final snapshot = await _snapshotter.createSnapshot();
    final clearBackup = _codec.encode(
      databaseBytes: snapshot,
      createdAtUtc: (createdAtUtc ?? DateTime.now()).toUtc(),
      schemaVersion: _schemaVersion,
      storageProfile: _storageProfile,
    );
    return _protector.protect(clearBackup);
  }
}
