import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';

enum RestoreProblem {
  profileMismatch,
  newerSchema,
  invalidDatabase,
  invalidRequest,
  missingRestoreArtifact,
  stagedArtifactChanged,
  applyFailed,
  rollbackFailed,
}

final class RestoreException implements Exception {
  const RestoreException(this.problem, this.message, [this.cause]);

  final RestoreProblem problem;
  final String message;
  final Object? cause;

  @override
  String toString() => 'RestoreException($problem): $message';
}

final class RestorePreview {
  const RestorePreview({required this.manifest});

  final BackupManifest manifest;
}

final class StagedRestore {
  const StagedRestore({
    required this.requestId,
    required this.preview,
  });

  final String requestId;
  final RestorePreview preview;
}

enum RestoreBootstrapOutcome { none, applied, rolledBack, discarded }
