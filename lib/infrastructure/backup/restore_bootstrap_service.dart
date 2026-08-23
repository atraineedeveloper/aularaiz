import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/data/local/storage_layout.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/aularaiz_database_file_validator.dart';
import 'package:aularaiz/infrastructure/backup/restore_request_marker.dart';
import 'package:crypto/crypto.dart';

typedef RestoreSafetySnapshotProvider = Future<Uint8List> Function();
typedef RestoreDatabaseOpenValidator = Future<void> Function(File file);

final class RestoreBootstrapService {
  RestoreBootstrapService({
    required StorageProfile profile,
    required int currentSchemaVersion,
    required RestoreSafetySnapshotProvider currentSnapshotProvider,
    required RestoreDatabaseOpenValidator restoredDatabaseOpener,
    ApplicationSupportDirectoryProvider directoryProvider =
        getApplicationSupportDirectory,
    AulaRaizDatabaseFileValidator validator =
        const AulaRaizDatabaseFileValidator(),
  }) : _profile = profile,
       _currentSchemaVersion = currentSchemaVersion,
       _currentSnapshotProvider = currentSnapshotProvider,
       _restoredDatabaseOpener = restoredDatabaseOpener,
       _directoryProvider = directoryProvider,
       _validator = validator;

  final StorageProfile _profile;
  final int _currentSchemaVersion;
  final RestoreSafetySnapshotProvider _currentSnapshotProvider;
  final RestoreDatabaseOpenValidator _restoredDatabaseOpener;
  final ApplicationSupportDirectoryProvider _directoryProvider;
  final AulaRaizDatabaseFileValidator _validator;

  Future<RestoreBootstrapOutcome> applyPending() async {
    final layout = await AulaRaizStorageLayout.resolve(
      _profile,
      directoryProvider: _directoryProvider,
    );
    if (!await layout.restoreMarkerFile.exists()) {
      return RestoreBootstrapOutcome.none;
    }

    late RestoreRequestMarker marker;
    try {
      marker = RestoreRequestMarker.decode(
        await layout.restoreMarkerFile.readAsString(),
      );
      if (marker.profile != _profile) {
        throw const RestoreException(
          RestoreProblem.profileMismatch,
          'Restore marker belongs to a different storage profile.',
        );
      }
    } on Object {
      await _discardManagedArtifacts(layout);
      return RestoreBootstrapOutcome.discarded;
    }

    if (marker.state == RestoreRequestState.applying) {
      return _rollbackAfterInterruptedApply(layout, marker);
    }

    try {
      await _validatePending(layout, marker);
      if (marker.state == RestoreRequestState.staged) {
        marker = await _prepareSafety(layout, marker);
      } else {
        await _validateSafety(layout, marker);
      }

      final applying = marker.copyWith(state: RestoreRequestState.applying);
      await _persistMarker(layout, applying);
      marker = applying;
    } on Object {
      await _discardManagedArtifacts(layout);
      return RestoreBootstrapOutcome.discarded;
    }

    try {
      await _replaceActiveWithPending(layout, marker);
      await _discardManagedArtifacts(layout);
      return RestoreBootstrapOutcome.applied;
    } on Object catch (applyError) {
      try {
        await _restoreSafety(layout, marker);
        await _discardManagedArtifacts(layout);
        return RestoreBootstrapOutcome.rolledBack;
      } on Object catch (rollbackError) {
        throw RestoreException(
          RestoreProblem.rollbackFailed,
          'Restore failed and the safety database could not be reapplied.',
          <Object>[applyError, rollbackError],
        );
      }
    }
  }

  Future<RestoreBootstrapOutcome> _rollbackAfterInterruptedApply(
    AulaRaizStorageLayout layout,
    RestoreRequestMarker marker,
  ) async {
    try {
      await _restoreSafety(layout, marker);
      await _discardManagedArtifacts(layout);
      return RestoreBootstrapOutcome.rolledBack;
    } on Object catch (error) {
      throw RestoreException(
        RestoreProblem.rollbackFailed,
        'An interrupted restore could not be rolled back safely.',
        error,
      );
    }
  }

  Future<RestoreRequestMarker> _prepareSafety(
    AulaRaizStorageLayout layout,
    RestoreRequestMarker marker,
  ) async {
    final safety = layout.safetyRestoreFile(marker.requestId);
    final safetyBytes = await _currentSnapshotProvider();
    await _writeFresh(safety, safetyBytes);
    await _validator.validate(
      safety,
      maxSchemaVersion: _currentSchemaVersion,
      exactSchemaVersion: _currentSchemaVersion,
    );
    final prepared = marker.copyWith(
      state: RestoreRequestState.prepared,
      safetySha256: sha256.convert(safetyBytes).toString(),
    );
    await _persistMarker(layout, prepared);
    return prepared;
  }

  Future<void> _validatePending(
    AulaRaizStorageLayout layout,
    RestoreRequestMarker marker,
  ) async {
    final pending = layout.pendingRestoreFile(marker.requestId);
    await _requireChecksum(pending, marker.pendingSha256);
    await _validator.validate(
      pending,
      maxSchemaVersion: _currentSchemaVersion,
      exactSchemaVersion: marker.sourceSchemaVersion,
    );
  }

  Future<void> _validateSafety(
    AulaRaizStorageLayout layout,
    RestoreRequestMarker marker,
  ) async {
    final expected = marker.safetySha256;
    if (expected == null) {
      throw const RestoreException(
        RestoreProblem.invalidRequest,
        'Prepared restore has no safety checksum.',
      );
    }
    final safety = layout.safetyRestoreFile(marker.requestId);
    await _requireChecksum(safety, expected);
    await _validator.validate(
      safety,
      maxSchemaVersion: _currentSchemaVersion,
      exactSchemaVersion: _currentSchemaVersion,
    );
  }

  Future<void> _replaceActiveWithPending(
    AulaRaizStorageLayout layout,
    RestoreRequestMarker marker,
  ) async {
    final pending = layout.pendingRestoreFile(marker.requestId);
    final applyTemp = layout.applyRestoreTempFile(marker.requestId);
    await _writeFresh(applyTemp, await pending.readAsBytes());
    await _replaceDatabaseFile(layout, applyTemp);
    await _restoredDatabaseOpener(layout.databaseFile);
    await _validator.validate(
      layout.databaseFile,
      maxSchemaVersion: _currentSchemaVersion,
      exactSchemaVersion: _currentSchemaVersion,
    );
  }

  Future<void> _restoreSafety(
    AulaRaizStorageLayout layout,
    RestoreRequestMarker marker,
  ) async {
    await _validateSafety(layout, marker);
    final safety = layout.safetyRestoreFile(marker.requestId);
    final rollbackTemp = layout.rollbackRestoreTempFile(marker.requestId);
    await _writeFresh(rollbackTemp, await safety.readAsBytes());
    await _replaceDatabaseFile(layout, rollbackTemp);
    await _restoredDatabaseOpener(layout.databaseFile);
    await _validator.validate(
      layout.databaseFile,
      maxSchemaVersion: _currentSchemaVersion,
      exactSchemaVersion: _currentSchemaVersion,
    );
  }

  Future<void> _replaceDatabaseFile(
    AulaRaizStorageLayout layout,
    File replacement,
  ) async {
    await _deleteIfPresent(layout.sidecar(layout.databaseFile, '-wal'));
    await _deleteIfPresent(layout.sidecar(layout.databaseFile, '-shm'));
    await _deleteIfPresent(layout.databaseFile);
    await replacement.rename(layout.databaseFile.path);
  }

  Future<void> _requireChecksum(File file, String expected) async {
    if (!await file.exists()) {
      throw const RestoreException(
        RestoreProblem.missingRestoreArtifact,
        'Restore artifact does not exist.',
      );
    }
    final actual = sha256.convert(await file.readAsBytes()).toString();
    if (actual != expected) {
      throw const RestoreException(
        RestoreProblem.stagedArtifactChanged,
        'Restore artifact checksum changed after staging.',
      );
    }
  }

  Future<void> _persistMarker(
    AulaRaizStorageLayout layout,
    RestoreRequestMarker marker,
  ) async {
    await _writeFresh(
      layout.restoreMarkerTempFile,
      Uint8List.fromList(utf8.encode(marker.encode())),
    );
    await _deleteIfPresent(layout.restoreMarkerFile);
    await layout.restoreMarkerTempFile.rename(layout.restoreMarkerFile.path);
  }

  Future<void> _discardManagedArtifacts(AulaRaizStorageLayout layout) async {
    if (!await layout.directory.exists()) return;
    await for (final entity in layout.directory.list()) {
      if (entity is File && layout.isManagedRestoreArtifact(entity)) {
        await _deleteIfPresent(entity);
      }
    }
  }

  Future<void> _writeFresh(File file, Uint8List bytes) async {
    await file.parent.create(recursive: true);
    await _deleteIfPresent(file);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}
