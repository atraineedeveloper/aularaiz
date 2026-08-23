import 'dart:convert';

import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/data/local/storage_profile.dart';

final class RestoreRequestMarker {
  const RestoreRequestMarker({
    required this.requestId,
    required this.profile,
    required this.stagedAtUtc,
    required this.backupCreatedAtUtc,
    required this.sourceSchemaVersion,
    required this.pendingSha256,
    required this.safetySha256,
  });

  factory RestoreRequestMarker.decode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic>) {
        throw const RestoreException(
          RestoreProblem.invalidRequest,
          'Restore marker must be a JSON object.',
        );
      }
      final version = decoded['version'];
      if (version != currentVersion) {
        throw const RestoreException(
          RestoreProblem.invalidRequest,
          'Restore marker version is not supported.',
        );
      }

      final requestId = _string(decoded, 'requestId');
      if (!_requestIdPattern.hasMatch(requestId)) {
        throw const RestoreException(
          RestoreProblem.invalidRequest,
          'Restore request identifier is invalid.',
        );
      }
      final profileName = _string(decoded, 'profile');
      final profile = StorageProfile.values.where((value) {
        return value.name == profileName;
      }).firstOrNull;
      if (profile == null) {
        throw const RestoreException(
          RestoreProblem.invalidRequest,
          'Restore marker profile is invalid.',
        );
      }

      final stagedAtUtc = DateTime.tryParse(_string(decoded, 'stagedAtUtc'))
          ?.toUtc();
      final backupCreatedAtUtc = DateTime.tryParse(
        _string(decoded, 'backupCreatedAtUtc'),
      )?.toUtc();
      if (stagedAtUtc == null || backupCreatedAtUtc == null) {
        throw const RestoreException(
          RestoreProblem.invalidRequest,
          'Restore marker timestamps are invalid.',
        );
      }

      return RestoreRequestMarker(
        requestId: requestId,
        profile: profile,
        stagedAtUtc: stagedAtUtc,
        backupCreatedAtUtc: backupCreatedAtUtc,
        sourceSchemaVersion: _integer(decoded, 'sourceSchemaVersion'),
        pendingSha256: _sha(decoded, 'pendingSha256'),
        safetySha256: _sha(decoded, 'safetySha256'),
      );
    } on RestoreException {
      rethrow;
    } on Object catch (error) {
      throw RestoreException(
        RestoreProblem.invalidRequest,
        'Restore marker is not valid JSON.',
        error,
      );
    }
  }

  static const int currentVersion = 1;
  static final RegExp _requestIdPattern = RegExp(r'^\d+-\d+-\d+$');
  static final RegExp _shaPattern = RegExp(r'^[0-9a-f]{64}$');

  final String requestId;
  final StorageProfile profile;
  final DateTime stagedAtUtc;
  final DateTime backupCreatedAtUtc;
  final int sourceSchemaVersion;
  final String pendingSha256;
  final String safetySha256;

  String encode() => jsonEncode(<String, Object?>{
    'version': currentVersion,
    'requestId': requestId,
    'profile': profile.name,
    'stagedAtUtc': stagedAtUtc.toUtc().toIso8601String(),
    'backupCreatedAtUtc': backupCreatedAtUtc.toUtc().toIso8601String(),
    'sourceSchemaVersion': sourceSchemaVersion,
    'pendingSha256': pendingSha256,
    'safetySha256': safetySha256,
  });

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw RestoreException(
      RestoreProblem.invalidRequest,
      '$key must be a non-empty string.',
    );
  }

  static int _integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int && value > 0) return value;
    throw RestoreException(
      RestoreProblem.invalidRequest,
      '$key must be a positive integer.',
    );
  }

  static String _sha(Map<String, dynamic> json, String key) {
    final value = _string(json, key);
    if (_shaPattern.hasMatch(value)) return value;
    throw RestoreException(
      RestoreProblem.invalidRequest,
      '$key must be a SHA-256 digest.',
    );
  }
}
