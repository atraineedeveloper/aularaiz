import 'dart:typed_data';

enum BackupProtectionProblem {
  invalidEnvelope,
  unsupportedProtection,
  keyUnavailable,
  keyMismatch,
  authenticationFailed,
}

final class BackupProtectionException implements Exception {
  const BackupProtectionException(this.problem, this.message);

  final BackupProtectionProblem problem;
  final String message;

  @override
  String toString() => 'BackupProtectionException($problem): $message';
}

abstract interface class BackupProtector {
  Future<Uint8List> protect(Uint8List clearBytes);

  Future<Uint8List> unprotect(Uint8List protectedOrLegacyBytes);
}

final class PassThroughBackupProtector implements BackupProtector {
  const PassThroughBackupProtector();

  @override
  Future<Uint8List> protect(Uint8List clearBytes) async =>
      Uint8List.fromList(clearBytes);

  @override
  Future<Uint8List> unprotect(Uint8List protectedOrLegacyBytes) async =>
      Uint8List.fromList(protectedOrLegacyBytes);
}
