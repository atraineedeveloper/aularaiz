import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum BackupFormatProblem {
  invalidMagic,
  truncated,
  invalidManifest,
  unsupportedVersion,
  unsupportedProtection,
  invalidProfile,
  invalidDatabase,
  checksumMismatch,
}

final class BackupFormatException implements Exception {
  const BackupFormatException(this.problem, this.message);

  final BackupFormatProblem problem;
  final String message;

  @override
  String toString() => 'BackupFormatException($problem): $message';
}

final class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.createdAtUtc,
    required this.schemaVersion,
    required this.storageProfile,
    required this.protection,
    required this.databaseSha256,
    required this.databaseLength,
  });

  static const currentFormatVersion = 1;

  final int formatVersion;
  final DateTime createdAtUtc;
  final int schemaVersion;
  final String storageProfile;
  final String protection;
  final String databaseSha256;
  final int databaseLength;

  Map<String, Object?> toJson() => <String, Object?>{
    'formatVersion': formatVersion,
    'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
    'schemaVersion': schemaVersion,
    'storageProfile': storageProfile,
    'protection': protection,
    'databaseSha256': databaseSha256,
    'databaseLength': databaseLength,
  };

  factory BackupManifest.fromJson(Map<String, Object?> json) {
    final formatVersion = _requiredInt(json, 'formatVersion');
    final createdAtText = _requiredString(json, 'createdAtUtc');
    final createdAtUtc = DateTime.tryParse(createdAtText)?.toUtc();
    if (createdAtUtc == null) {
      throw const BackupFormatException(
        BackupFormatProblem.invalidManifest,
        'createdAtUtc is not a valid timestamp.',
      );
    }

    return BackupManifest(
      formatVersion: formatVersion,
      createdAtUtc: createdAtUtc,
      schemaVersion: _requiredInt(json, 'schemaVersion'),
      storageProfile: _requiredString(json, 'storageProfile'),
      protection: _requiredString(json, 'protection'),
      databaseSha256: _requiredString(json, 'databaseSha256'),
      databaseLength: _requiredInt(json, 'databaseLength'),
    );
  }

  static String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw BackupFormatException(
      BackupFormatProblem.invalidManifest,
      '$key must be a non-empty string.',
    );
  }

  static int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw BackupFormatException(
      BackupFormatProblem.invalidManifest,
      '$key must be an integer.',
    );
  }
}

final class BackupInspection {
  const BackupInspection({
    required this.manifest,
    required this.databaseBytes,
  });

  final BackupManifest manifest;
  final Uint8List databaseBytes;
}

final class AulaRaizBackupCodec {
  const AulaRaizBackupCodec();

  static final Uint8List _magic = Uint8List.fromList(
    utf8.encode('AULARAIZ_BACKUP\n'),
  );
  static final Uint8List _sqliteHeader = Uint8List.fromList(
    ascii.encode('SQLite format 3\u0000'),
  );
  static const int _manifestLengthBytes = 4;
  static const int _maxManifestBytes = 256 * 1024;
  static const Set<String> _supportedProfiles = <String>{'production', 'demo'};

  Uint8List encode({
    required Uint8List databaseBytes,
    required DateTime createdAtUtc,
    required int schemaVersion,
    required String storageProfile,
  }) {
    _validateSqlite(databaseBytes);
    if (!_supportedProfiles.contains(storageProfile)) {
      throw BackupFormatException(
        BackupFormatProblem.invalidProfile,
        'Unsupported storage profile: $storageProfile.',
      );
    }
    if (schemaVersion <= 0) {
      throw const BackupFormatException(
        BackupFormatProblem.invalidManifest,
        'schemaVersion must be greater than zero.',
      );
    }

    final manifest = BackupManifest(
      formatVersion: BackupManifest.currentFormatVersion,
      createdAtUtc: createdAtUtc.toUtc(),
      schemaVersion: schemaVersion,
      storageProfile: storageProfile,
      protection: 'none',
      databaseSha256: sha256.convert(databaseBytes).toString(),
      databaseLength: databaseBytes.length,
    );
    final manifestBytes = utf8.encode(jsonEncode(manifest.toJson()));
    if (manifestBytes.length > _maxManifestBytes) {
      throw const BackupFormatException(
        BackupFormatProblem.invalidManifest,
        'Backup manifest is unexpectedly large.',
      );
    }

    final lengthBytes = ByteData(_manifestLengthBytes)
      ..setUint32(0, manifestBytes.length, Endian.big);
    final builder = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(lengthBytes.buffer.asUint8List())
      ..add(manifestBytes)
      ..add(databaseBytes);
    return builder.takeBytes();
  }

  BackupInspection inspect(Uint8List bytes) {
    final minimumLength = _magic.length + _manifestLengthBytes;
    if (bytes.length < minimumLength) {
      throw const BackupFormatException(
        BackupFormatProblem.truncated,
        'Backup is too short to contain a header.',
      );
    }
    if (!_startsWith(bytes, _magic)) {
      throw const BackupFormatException(
        BackupFormatProblem.invalidMagic,
        'File is not an AulaRaíz backup.',
      );
    }

    final lengthOffset = _magic.length;
    final manifestLength = ByteData.sublistView(
      bytes,
      lengthOffset,
      lengthOffset + _manifestLengthBytes,
    ).getUint32(0, Endian.big);
    if (manifestLength <= 0 || manifestLength > _maxManifestBytes) {
      throw const BackupFormatException(
        BackupFormatProblem.invalidManifest,
        'Manifest length is invalid.',
      );
    }

    final manifestOffset = lengthOffset + _manifestLengthBytes;
    final databaseOffset = manifestOffset + manifestLength;
    if (databaseOffset > bytes.length) {
      throw const BackupFormatException(
        BackupFormatProblem.truncated,
        'Backup ended before the manifest was complete.',
      );
    }

    final manifest = _decodeManifest(
      Uint8List.fromList(bytes.sublist(manifestOffset, databaseOffset)),
    );
    if (manifest.formatVersion != BackupManifest.currentFormatVersion) {
      throw BackupFormatException(
        BackupFormatProblem.unsupportedVersion,
        'Backup format ${manifest.formatVersion} is not supported.',
      );
    }
    if (manifest.protection != 'none') {
      throw BackupFormatException(
        BackupFormatProblem.unsupportedProtection,
        'Backup protection ${manifest.protection} is not supported.',
      );
    }
    if (!_supportedProfiles.contains(manifest.storageProfile)) {
      throw BackupFormatException(
        BackupFormatProblem.invalidProfile,
        'Backup profile ${manifest.storageProfile} is not supported.',
      );
    }
    if (manifest.schemaVersion <= 0) {
      throw const BackupFormatException(
        BackupFormatProblem.invalidManifest,
        'Backup schemaVersion must be greater than zero.',
      );
    }

    final databaseBytes = Uint8List.fromList(bytes.sublist(databaseOffset));
    if (databaseBytes.length != manifest.databaseLength) {
      throw const BackupFormatException(
        BackupFormatProblem.truncated,
        'Database length does not match the manifest.',
      );
    }
    _validateSqlite(databaseBytes);

    final actualChecksum = sha256.convert(databaseBytes).toString();
    if (actualChecksum != manifest.databaseSha256) {
      throw const BackupFormatException(
        BackupFormatProblem.checksumMismatch,
        'Database checksum does not match the manifest.',
      );
    }

    return BackupInspection(manifest: manifest, databaseBytes: databaseBytes);
  }

  BackupManifest _decodeManifest(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BackupFormatException(
          BackupFormatProblem.invalidManifest,
          'Backup manifest must be a JSON object.',
        );
      }
      return BackupManifest.fromJson(Map<String, Object?>.from(decoded));
    } on BackupFormatException {
      rethrow;
    } on Object {
      throw const BackupFormatException(
        BackupFormatProblem.invalidManifest,
        'Backup manifest is not valid JSON.',
      );
    }
  }

  void _validateSqlite(Uint8List bytes) {
    if (bytes.length < _sqliteHeader.length || !_startsWith(bytes, _sqliteHeader)) {
      throw const BackupFormatException(
        BackupFormatProblem.invalidDatabase,
        'Backup payload is not a SQLite 3 database.',
      );
    }
  }

  bool _startsWith(Uint8List value, Uint8List prefix) {
    if (value.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index += 1) {
      if (value[index] != prefix[index]) return false;
    }
    return true;
  }
}
