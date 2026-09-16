import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/create_backup.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/application/contracts/database_snapshotter.dart';
import 'package:aularaiz/data/local/storage_layout.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/backup_content_summary_reader.dart';
import 'package:aularaiz/infrastructure/backup/local_backup_transfer_server.dart';
import 'package:aularaiz/infrastructure/backup/portable_backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/restore_staging_service.dart';
import 'package:aularaiz/infrastructure/reports/report_publication_service.dart';
import 'package:aularaiz/infrastructure/sync/record_level_sync_service.dart';
import 'package:aularaiz/infrastructure/sync/sync_device_registry.dart';
import 'package:aularaiz/infrastructure/sync/sync_refresh_notifier.dart';
import 'package:file_selector/file_selector.dart';

final class BackupSelection {
  const BackupSelection({
    required this.bytes,
    required this.preview,
    this.restoreProtector,
  });

  final Uint8List bytes;
  final RestorePreview preview;
  final BackupProtector? restoreProtector;
}

final class PortableBackupExport {
  const PortableBackupExport({required this.transferCode});

  final String transferCode;
}

abstract interface class BackupRestoreGateway {
  Future<bool> hasPendingRestore();

  Future<bool> exportBackup();

  Future<PortableBackupExport?> exportPortableBackup();

  Future<PortableBackupTransferSession> startPortableBackupTransfer();

  Future<BackupSelection?> selectBackup();

  Future<BackupSelection?> selectPortableBackup({required String transferCode});

  Future<BackupContentSummary> currentContentSummary();

  Future<BackupSelection> receivePortableBackupSelectionFromUrl({
    required String downloadUrl,
    required String transferCode,
  });

  Future<StagedRestore> receivePortableBackupFromUrl({
    required String downloadUrl,
    required String transferCode,
  });

  Future<StagedRestore> stageRestore(BackupSelection selection);

  Future<RecordLevelSyncSummary> mergeIncomingBackup(BackupSelection selection);

  Future<RecordLevelSyncSummary?> pushCurrentBackupToUrl({
    required String uploadUrl,
    required String transferCode,
  });
}

final class PlatformBackupRestoreGateway implements BackupRestoreGateway {
  const PlatformBackupRestoreGateway({
    required CreateBackup createBackup,
    required DatabaseSnapshotter snapshotter,
    required int schemaVersion,
    required String storageProfile,
    required RestoreStagingService restoreStagingService,
    required ReportPublicationService publicationService,
    RecordLevelSyncService? recordLevelSyncService,
    SyncDeviceRegistry? syncDeviceRegistry,
    SyncRefreshNotifier? syncRefreshNotifier,
    BackupContentSummaryReader summaryReader =
        const BackupContentSummaryReader(),
  }) : _createBackup = createBackup,
       _snapshotter = snapshotter,
       _schemaVersion = schemaVersion,
       _storageProfile = storageProfile,
       _restoreStagingService = restoreStagingService,
       _publicationService = publicationService,
       _recordLevelSyncService = recordLevelSyncService,
       _syncDeviceRegistry = syncDeviceRegistry,
       _syncRefreshNotifier = syncRefreshNotifier,
       _summaryReader = summaryReader;

  final CreateBackup _createBackup;
  final DatabaseSnapshotter _snapshotter;
  final int _schemaVersion;
  final String _storageProfile;
  final RestoreStagingService _restoreStagingService;
  final ReportPublicationService _publicationService;
  final RecordLevelSyncService? _recordLevelSyncService;
  final SyncDeviceRegistry? _syncDeviceRegistry;
  final SyncRefreshNotifier? _syncRefreshNotifier;
  final BackupContentSummaryReader _summaryReader;
  final AulaRaizBackupCodec _codec = const AulaRaizBackupCodec();

  @override
  Future<bool> hasPendingRestore() {
    return _restoreStagingService.hasPendingRequest();
  }

  @override
  Future<bool> exportBackup() async {
    final createdAtUtc = DateTime.now().toUtc();
    final bytes = await _createBackup(createdAtUtc: createdAtUtc);
    return _publicationService.publishFile(
      bytes: bytes,
      fileName: buildAulaRaizBackupFileName(createdAtUtc),
      mimeType: 'application/octet-stream',
      extension: 'aularaiz',
      typeLabel: 'AulaRaíz backup',
    );
  }

  @override
  Future<PortableBackupExport?> exportPortableBackup() async {
    final createdAtUtc = DateTime.now().toUtc();
    final transferCode = generatePortableBackupTransferCode();
    final bytes = await CreateBackup(
      snapshotter: _snapshotter,
      schemaVersion: _schemaVersion,
      storageProfile: _storageProfile,
      protector: PortableBackupProtector(transferCode: transferCode),
    )(createdAtUtc: createdAtUtc);
    final published = await _publicationService.publishFile(
      bytes: bytes,
      fileName: buildAulaRaizPortableBackupFileName(createdAtUtc),
      mimeType: 'application/octet-stream',
      extension: 'aularaiz',
      typeLabel: 'AulaRaíz portable backup',
    );
    if (!published) return null;
    return PortableBackupExport(transferCode: transferCode);
  }

  @override
  Future<PortableBackupTransferSession> startPortableBackupTransfer() async {
    final identity = await _syncDeviceRegistry?.identity();
    return LocalBackupTransferServer(
      snapshotter: _snapshotter,
      schemaVersion: _schemaVersion,
      storageProfile: _storageProfile,
      uploadHandler: _recordLevelSyncService == null
          ? null
          : ({
              required bytes,
              required transferCode,
              sourceDeviceId,
              sourceDeviceName,
            }) async {
              final summary = await _recordLevelSyncService.mergeBackup(
                backupBytes: bytes,
                protector: PortableBackupProtector(transferCode: transferCode),
              );
              final normalizedDeviceId = sourceDeviceId?.trim();
              if (normalizedDeviceId != null &&
                  normalizedDeviceId.isNotEmpty &&
                  normalizedDeviceId != identity?.id) {
                await _syncDeviceRegistry?.rememberLinkedDevice(
                  id: normalizedDeviceId,
                  name: sourceDeviceName?.trim().isNotEmpty == true
                      ? sourceDeviceName!.trim()
                      : 'Dispositivo AulaRa\u00EDz',
                );
              }
              _notifySyncChanged(summary);
              return summary;
            },
      sourceDeviceId: identity?.id,
      sourceDeviceName: identity?.name,
    ).start();
  }

  @override
  Future<BackupSelection?> selectBackup() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: 'AulaRaíz backup', extensions: <String>['aularaiz']),
      ],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final preview = await _restoreStagingService.inspect(bytes);
    return BackupSelection(bytes: bytes, preview: preview);
  }

  @override
  Future<BackupSelection?> selectPortableBackup({
    required String transferCode,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: 'AulaRaíz backup', extensions: <String>['aularaiz']),
      ],
    );
    if (file == null) return null;

    final protector = PortableBackupProtector(transferCode: transferCode);
    final bytes = await file.readAsBytes();
    return _inspectSelection(bytes: bytes, protector: protector);
  }

  @override
  Future<BackupContentSummary> currentContentSummary() async {
    final snapshot = await _snapshotter.createSnapshot();
    final summary = await _summaryReader.read(snapshot);
    return summary.copyWith(localModifiedAtUtc: await _currentModifiedAtUtc());
  }

  @override
  Future<BackupSelection> receivePortableBackupSelectionFromUrl({
    required String downloadUrl,
    required String transferCode,
  }) async {
    final bytes = await _downloadPortableBackup(downloadUrl);
    final protector = PortableBackupProtector(transferCode: transferCode);
    return _inspectSelection(bytes: bytes, protector: protector);
  }

  @override
  Future<StagedRestore> receivePortableBackupFromUrl({
    required String downloadUrl,
    required String transferCode,
  }) async {
    final selection = await receivePortableBackupSelectionFromUrl(
      downloadUrl: downloadUrl,
      transferCode: transferCode,
    );
    return stageRestore(selection);
  }

  @override
  Future<StagedRestore> stageRestore(BackupSelection selection) {
    final protector = selection.restoreProtector;
    final service = protector == null
        ? _restoreStagingService
        : _restoreStagingService.withProtector(protector);
    return service.stage(selection.bytes);
  }

  @override
  Future<RecordLevelSyncSummary> mergeIncomingBackup(
    BackupSelection selection,
  ) async {
    final service = _recordLevelSyncService;
    final protector = selection.restoreProtector;
    if (service == null || protector == null) {
      throw StateError('Record-level sync is not available.');
    }
    final summary = await service.mergeBackup(
      backupBytes: selection.bytes,
      protector: protector,
    );
    _notifySyncChanged(summary);
    return summary;
  }

  @override
  Future<RecordLevelSyncSummary?> pushCurrentBackupToUrl({
    required String uploadUrl,
    required String transferCode,
  }) async {
    final parsedUri = Uri.tryParse(uploadUrl);
    if (parsedUri == null ||
        (parsedUri.scheme != 'http' && parsedUri.scheme != 'https')) {
      return null;
    }
    final identity = await _syncDeviceRegistry?.identity();
    final uri = identity == null
        ? parsedUri
        : parsedUri.replace(
            queryParameters: <String, String>{
              ...parsedUri.queryParameters,
              'deviceId': identity.id,
              'deviceName': identity.name,
            },
          );

    final createdAtUtc = DateTime.now().toUtc();
    final bytes = await CreateBackup(
      snapshotter: _snapshotter,
      schemaVersion: _schemaVersion,
      storageProfile: _storageProfile,
      protector: PortableBackupProtector(transferCode: transferCode),
    )(createdAtUtc: createdAtUtc);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.binary;
      request.headers.contentLength = bytes.length;
      request.add(bytes);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) return null;
      return RecordLevelSyncSummary(
        inserted: decoded['inserted'] is int ? decoded['inserted']! as int : 0,
        updated: decoded['updated'] is int ? decoded['updated']! as int : 0,
        skipped: decoded['skipped'] is int ? decoded['skipped']! as int : 0,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<BackupSelection> _inspectSelection({
    required Uint8List bytes,
    required BackupProtector protector,
  }) async {
    final service = _restoreStagingService.withProtector(protector);
    final preview = await service.inspect(bytes);
    final clearBytes = await protector.unprotect(bytes);
    final inspection = _codec.inspect(clearBytes);
    final summary = await _summaryReader.read(inspection.databaseBytes);
    return BackupSelection(
      bytes: bytes,
      preview: RestorePreview(manifest: preview.manifest, summary: summary),
      restoreProtector: protector,
    );
  }

  Future<DateTime?> _currentModifiedAtUtc() async {
    final profile = switch (_storageProfile) {
      'production' => StorageProfile.production,
      'demo' => StorageProfile.demo,
      _ => null,
    };
    if (profile == null) return null;
    final layout = await AulaRaizStorageLayout.resolve(profile);
    if (!await layout.databaseFile.exists()) return null;
    return layout.databaseFile.lastModified().then((value) => value.toUtc());
  }

  Future<Uint8List> _downloadPortableBackup(String downloadUrl) async {
    final uri = Uri.tryParse(downloadUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const FormatException('Transfer link is not a valid HTTP URL.');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Transfer download returned HTTP ${response.statusCode}.',
          uri: uri,
        );
      }

      const maxBytes = 250 * 1024 * 1024;
      final builder = BytesBuilder(copy: false);
      var total = 0;
      await for (final chunk in response) {
        total += chunk.length;
        if (total > maxBytes) {
          throw const HttpException('Transfer backup is too large.');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  void _notifySyncChanged(RecordLevelSyncSummary summary) {
    if (summary.changed == 0) return;
    _syncRefreshNotifier?.markDataChanged();
  }
}

String buildAulaRaizBackupFileName(DateTime createdAtUtc) {
  final value = createdAtUtc.toUtc();
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return 'aularaiz-backup-$year$month$day-$hour$minute$second.aularaiz';
}

String buildAulaRaizPortableBackupFileName(DateTime createdAtUtc) {
  final value = createdAtUtc.toUtc();
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return 'aularaiz-transfer-$year$month$day-$hour$minute$second.aularaiz';
}
