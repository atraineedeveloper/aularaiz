import 'dart:typed_data';

import 'package:aularaiz/application/backup/create_backup.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/infrastructure/backup/restore_staging_service.dart';
import 'package:aularaiz/infrastructure/reports/report_publication_service.dart';
import 'package:file_selector/file_selector.dart';

final class BackupSelection {
  const BackupSelection({required this.bytes, required this.preview});

  final Uint8List bytes;
  final RestorePreview preview;
}

abstract interface class BackupRestoreGateway {
  Future<bool> exportBackup();

  Future<BackupSelection?> selectBackup();

  Future<StagedRestore> stageRestore(BackupSelection selection);
}

final class PlatformBackupRestoreGateway implements BackupRestoreGateway {
  const PlatformBackupRestoreGateway({
    required CreateBackup createBackup,
    required RestoreStagingService restoreStagingService,
    required ReportPublicationService publicationService,
  }) : _createBackup = createBackup,
       _restoreStagingService = restoreStagingService,
       _publicationService = publicationService;

  final CreateBackup _createBackup;
  final RestoreStagingService _restoreStagingService;
  final ReportPublicationService _publicationService;

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
  Future<BackupSelection?> selectBackup() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: 'AulaRaíz backup',
          extensions: <String>['aularaiz'],
        ),
      ],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final preview = _restoreStagingService.inspect(bytes);
    return BackupSelection(bytes: bytes, preview: preview);
  }

  @override
  Future<StagedRestore> stageRestore(BackupSelection selection) {
    return _restoreStagingService.stage(selection.bytes);
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
