import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/data/local/storage_layout.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/aularaiz_database_file_validator.dart';
import 'package:aularaiz/infrastructure/backup/restore_request_marker.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

final class RestoreStagingService {
  RestoreStagingService({
    required StorageProfile profile,
    required int currentSchemaVersion,
    ApplicationSupportDirectoryProvider directoryProvider =
        getApplicationSupportDirectory,
    AulaRaizBackupCodec codec = const AulaRaizBackupCodec(),
    BackupProtector protector = const PassThroughBackupProtector(),
    AulaRaizDatabaseFileValidator validator =
        const AulaRaizDatabaseFileValidator(),
  }) : _profile = profile,
       _currentSchemaVersion = currentSchemaVersion,
       _directoryProvider = directoryProvider,
       _codec = codec,
       _protector = protector,
       _validator = validator;

  final StorageProfile _profile;
  final int _currentSchemaVersion;
  final ApplicationSupportDirectoryProvider _directoryProvider;
  final AulaRaizBackupCodec _codec;
  final BackupProtector _protector;
  final AulaRaizDatabaseFileValidator _validator;

  static int _sequence = 0;

  Future<bool> hasPendingRequest() async {
    final layout = await AulaRaizStorageLayout.resolve(
      _profile,
      directoryProvider: _directoryProvider,
    );
    return layout.restoreMarkerFile.exists();
  }

  Future<RestorePreview> inspect(Uint8List backupBytes) async {
    final clearBackupBytes = await _protector.unprotect(backupBytes);
    final inspection = _codec.inspect(clearBackupBytes);
    _validateCompatibility(inspection.manifest);
    return RestorePreview(manifest: inspection.manifest);
  }

  Future<StagedRestore> stage(Uint8List backupBytes) async {
    final clearBackupBytes = await _protector.unprotect(backupBytes);
    final inspection = _codec.inspect(clearBackupBytes);
    _validateCompatibility(inspection.manifest);
    final preview = RestorePreview(manifest: inspection.manifest);
    final layout = await AulaRaizStorageLayout.resolve(
      _profile,
      directoryProvider: _directoryProvider,
    );
    final requestId = _newRequestId();
    final pending = layout.pendingRestoreFile(requestId);
    final markerTemp = layout.restoreMarkerTempFile;
    var committed = false;

    try {
      await _writeFresh(pending, inspection.databaseBytes);
      await _validator.validate(
        pending,
        maxSchemaVersion: _currentSchemaVersion,
        exactSchemaVersion: inspection.manifest.schemaVersion,
      );

      final marker = RestoreRequestMarker(
        requestId: requestId,
        profile: _profile,
        state: RestoreRequestState.staged,
        stagedAtUtc: DateTime.now().toUtc(),
        backupCreatedAtUtc: inspection.manifest.createdAtUtc,
        sourceSchemaVersion: inspection.manifest.schemaVersion,
        pendingSha256: sha256.convert(await pending.readAsBytes()).toString(),
      );
      await _writeFresh(
        markerTemp,
        Uint8List.fromList(utf8.encode(marker.encode())),
      );
      await _deleteIfPresent(layout.restoreMarkerFile);
      await markerTemp.rename(layout.restoreMarkerFile.path);
      committed = true;
      await _cleanupStaleArtifacts(
        layout,
        keep: <String>{layout.restoreMarkerFile.path, pending.path},
      );
      return StagedRestore(requestId: requestId, preview: preview);
    } finally {
      if (!committed) {
        await _deleteIfPresent(pending);
        await _deleteIfPresent(markerTemp);
      }
    }
  }

  void _validateCompatibility(BackupManifest manifest) {
    if (manifest.storageProfile != _profile.name) {
      throw RestoreException(
        RestoreProblem.profileMismatch,
        'Backup profile ${manifest.storageProfile} cannot restore ${_profile.name}.',
      );
    }
    if (manifest.schemaVersion > _currentSchemaVersion) {
      throw RestoreException(
        RestoreProblem.newerSchema,
        'Backup schema ${manifest.schemaVersion} is newer than supported schema $_currentSchemaVersion.',
      );
    }
  }

  String _newRequestId() {
    final sequence = _sequence++;
    return '${DateTime.now().microsecondsSinceEpoch}-$pid-$sequence';
  }

  Future<void> _writeFresh(File file, Uint8List bytes) async {
    await file.parent.create(recursive: true);
    await _deleteIfPresent(file);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _cleanupStaleArtifacts(
    AulaRaizStorageLayout layout, {
    required Set<String> keep,
  }) async {
    await for (final entity in layout.directory.list()) {
      if (entity is! File || !layout.isManagedRestoreArtifact(entity)) continue;
      if (keep.contains(entity.path)) continue;
      await _deleteIfPresent(entity);
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}
