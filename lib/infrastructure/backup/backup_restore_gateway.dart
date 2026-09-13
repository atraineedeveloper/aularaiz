import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/create_backup.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/application/contracts/database_snapshotter.dart';
import 'package:aularaiz/infrastructure/backup/local_backup_transfer_server.dart';
import 'package:aularaiz/infrastructure/backup/portable_backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/restore_staging_service.dart';
import 'package:aularaiz/infrastructure/reports/report_publication_service.dart';
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

  Future<StagedRestore> receivePortableBackupFromUrl({
    required String downloadUrl,
    required String transferCode,
  });

  Future<StagedRestore> stageRestore(BackupSelection selection);
}

final class PlatformBackupRestoreGateway implements BackupRestoreGateway {
  const PlatformBackupRestoreGateway({
    required CreateBackup createBackup,
    required DatabaseSnapshotter snapshotter,
    required int schemaVersion,
    required String storageProfile,
    required RestoreStagingService restoreStagingService,
    required ReportPublicationService publicationService,
  }) : _createBackup = createBackup,
       _snapshotter = snapshotter,
       _schemaVersion = schemaVersion,
       _storageProfile = storageProfile,
       _restoreStagingService = restoreStagingService,
       _publicationService = publicationService;

  final CreateBackup _createBackup;
  final DatabaseSnapshotter _snapshotter;
  final int _schemaVersion;
  final String _storageProfile;
  final RestoreStagingService _restoreStagingService;
  final ReportPublicationService _publicationService;

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
  Future<PortableBackupTransferSession> startPortableBackupTransfer() {
    return LocalBackupTransferServer(
      snapshotter: _snapshotter,
      schemaVersion: _schemaVersion,
      storageProfile: _storageProfile,
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
    final service = _restoreStagingService.withProtector(protector);
    final bytes = await file.readAsBytes();
    final preview = await service.inspect(bytes);
    return BackupSelection(
      bytes: bytes,
      preview: preview,
      restoreProtector: protector,
    );
  }

  @override
  Future<StagedRestore> receivePortableBackupFromUrl({
    required String downloadUrl,
    required String transferCode,
  }) async {
    final bytes = await _downloadPortableBackup(downloadUrl);
    final protector = PortableBackupProtector(transferCode: transferCode);
    final service = _restoreStagingService.withProtector(protector);
    return service.stage(bytes);
  }

  @override
  Future<StagedRestore> stageRestore(BackupSelection selection) {
    final protector = selection.restoreProtector;
    final service = protector == null
        ? _restoreStagingService
        : _restoreStagingService.withProtector(protector);
    return service.stage(selection.bytes);
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
