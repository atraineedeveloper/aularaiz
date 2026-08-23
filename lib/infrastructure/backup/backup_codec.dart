import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/backup_models.dart';
import 'package:cryptography/cryptography.dart';

final class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

final class BackupIntegrityException implements Exception {
  const BackupIntegrityException();

  @override
  String toString() => 'BackupIntegrityException: checksum mismatch';
}

final class BackupPasswordRequiredException implements Exception {
  const BackupPasswordRequiredException();

  @override
  String toString() => 'BackupPasswordRequiredException';
}

final class BackupAuthenticationException implements Exception {
  const BackupAuthenticationException();

  @override
  String toString() => 'BackupAuthenticationException';
}

final class BackupCodec {
  BackupCodec({
    int argon2Memory = 19456,
    int argon2Iterations = 2,
    int argon2Parallelism = 1,
    Random? random,
  }) : _argon2Memory = argon2Memory,
       _argon2Iterations = argon2Iterations,
       _argon2Parallelism = argon2Parallelism,
       _random = random ?? Random.secure() {
    _validateKdfParameters(
      memory: argon2Memory,
      iterations: argon2Iterations,
      parallelism: argon2Parallelism,
      hashLength: _keyLength,
    );
  }

  static const String _format = 'aularaiz-backup';
  static const int _formatVersion = 1;
  static const int _keyLength = 32;
  static const int _saltLength = 16;
  static const int _minimumArgon2Memory = 8192;
  static const int _maximumArgon2Memory = 65536;
  static const int _maximumArgon2Iterations = 10;
  static const int _maximumArgon2Parallelism = 4;
  static const List<int> _sqliteHeader = <int>[
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];

  final int _argon2Memory;
  final int _argon2Iterations;
  final int _argon2Parallelism;
  final Random _random;

  Future<Uint8List> encode({
    required Uint8List sqliteBytes,
    required DateTime createdAt,
    required int schemaVersion,
    required String storageProfile,
    String? password,
  }) async {
    _validateSqlitePayload(sqliteBytes);
    if (schemaVersion <= 0) {
      throw ArgumentError.value(schemaVersion, 'schemaVersion');
    }
    if (storageProfile.trim().isEmpty) {
      throw ArgumentError.value(storageProfile, 'storageProfile');
    }
    if (password != null && password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'Password is empty.');
    }

    Uint8List storedPayload = Uint8List.fromList(sqliteBytes);
    Map<String, Object?>? encryption;
    final protection = password == null
        ? BackupProtection.none
        : BackupProtection.password;

    if (password != null) {
      final salt = _randomBytes(_saltLength);
      final kdf = Argon2id(
        memory: _argon2Memory,
        parallelism: _argon2Parallelism,
        iterations: _argon2Iterations,
        hashLength: _keyLength,
      );
      final secretKey = await kdf.deriveKeyFromPassword(
        password: password,
        nonce: salt,
      );
      final cipher = AesGcm.with256bits();
      final nonce = cipher.newNonce();
      final box = await cipher.encrypt(
        sqliteBytes,
        secretKey: secretKey,
        nonce: nonce,
      );
      storedPayload = Uint8List.fromList(box.cipherText);
      encryption = <String, Object?>{
        'algorithm': 'aes-256-gcm',
        'kdf': 'argon2id',
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'memory': _argon2Memory,
        'iterations': _argon2Iterations,
        'parallelism': _argon2Parallelism,
        'hashLength': _keyLength,
      };
    }

    final payloadSha256 = await _sha256Hex(storedPayload);
    final document = <String, Object?>{
      'format': _format,
      'formatVersion': _formatVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'schemaVersion': schemaVersion,
      'storageProfile': storageProfile,
      'protection': protection.name,
      'payloadLength': storedPayload.length,
      'payloadSha256': payloadSha256,
      if (encryption != null) 'encryption': encryption,
      'payload': base64Encode(storedPayload),
    };

    return Uint8List.fromList(utf8.encode(jsonEncode(document)));
  }

  Future<BackupInspection> inspect(Uint8List containerBytes) async {
    final parsed = await _parse(containerBytes);
    return parsed.inspection;
  }

  Future<DecodedBackup> decode(
    Uint8List containerBytes, {
    String? password,
  }) async {
    final parsed = await _parse(containerBytes);
    Uint8List sqliteBytes;

    switch (parsed.inspection.protection) {
      case BackupProtection.none:
        sqliteBytes = Uint8List.fromList(parsed.payload);
      case BackupProtection.password:
        if (password == null || password.isEmpty) {
          throw const BackupPasswordRequiredException();
        }
        final encryption = parsed.encryption;
        if (encryption == null) {
          throw const BackupFormatException(
            'Password-protected backup has no encryption metadata.',
          );
        }

        final memory = _requiredInt(encryption, 'memory');
        final iterations = _requiredInt(encryption, 'iterations');
        final parallelism = _requiredInt(encryption, 'parallelism');
        final hashLength = _requiredInt(encryption, 'hashLength');
        _validateKdfParameters(
          memory: memory,
          iterations: iterations,
          parallelism: parallelism,
          hashLength: hashLength,
        );
        if (_requiredString(encryption, 'algorithm') != 'aes-256-gcm' ||
            _requiredString(encryption, 'kdf') != 'argon2id') {
          throw const BackupFormatException('Unsupported encryption scheme.');
        }

        final salt = _decodeBase64Field(encryption, 'salt');
        final nonce = _decodeBase64Field(encryption, 'nonce');
        final mac = _decodeBase64Field(encryption, 'mac');
        if (salt.length != _saltLength ||
            nonce.length != 12 ||
            mac.length != 16) {
          throw const BackupFormatException('Invalid encryption metadata.');
        }

        final kdf = Argon2id(
          memory: memory,
          parallelism: parallelism,
          iterations: iterations,
          hashLength: hashLength,
        );
        final secretKey = await kdf.deriveKeyFromPassword(
          password: password,
          nonce: salt,
        );
        try {
          final clearText = await AesGcm.with256bits().decrypt(
            SecretBox(parsed.payload, nonce: nonce, mac: Mac(mac)),
            secretKey: secretKey,
          );
          sqliteBytes = Uint8List.fromList(clearText);
        } on SecretBoxAuthenticationError {
          throw const BackupAuthenticationException();
        }
    }

    _validateSqlitePayload(sqliteBytes);
    return DecodedBackup(
      inspection: parsed.inspection,
      sqliteBytes: sqliteBytes,
    );
  }

  Future<_ParsedBackup> _parse(Uint8List containerBytes) async {
    try {
      final decoded = jsonDecode(utf8.decode(containerBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BackupFormatException('Backup root is not an object.');
      }
      if (_requiredString(decoded, 'format') != _format) {
        throw const BackupFormatException('Unknown backup format.');
      }

      final formatVersion = _requiredInt(decoded, 'formatVersion');
      if (formatVersion != _formatVersion) {
        throw const BackupFormatException('Unsupported backup version.');
      }
      final createdAt = DateTime.tryParse(
        _requiredString(decoded, 'createdAt'),
      );
      if (createdAt == null) {
        throw const BackupFormatException('Invalid backup creation date.');
      }
      final schemaVersion = _requiredInt(decoded, 'schemaVersion');
      if (schemaVersion <= 0) {
        throw const BackupFormatException('Invalid schema version.');
      }
      final storageProfile = _requiredString(decoded, 'storageProfile');
      if (storageProfile.isEmpty) {
        throw const BackupFormatException('Invalid storage profile.');
      }
      final protection = switch (_requiredString(decoded, 'protection')) {
        'none' => BackupProtection.none,
        'password' => BackupProtection.password,
        _ => throw const BackupFormatException(
          'Unsupported backup protection.',
        ),
      };

      final payload = _decodeBase64Field(decoded, 'payload');
      final payloadLength = _requiredInt(decoded, 'payloadLength');
      if (payloadLength != payload.length) {
        throw const BackupIntegrityException();
      }
      final expectedHash = _requiredString(decoded, 'payloadSha256');
      if (expectedHash.length != 64 ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash)) {
        throw const BackupFormatException('Invalid checksum metadata.');
      }
      final actualHash = await _sha256Hex(payload);
      if (actualHash != expectedHash) {
        throw const BackupIntegrityException();
      }

      Map<String, dynamic>? encryption;
      final encryptionValue = decoded['encryption'];
      if (encryptionValue != null) {
        if (encryptionValue is! Map<String, dynamic>) {
          throw const BackupFormatException('Invalid encryption metadata.');
        }
        encryption = encryptionValue;
      }
      if (protection == BackupProtection.password && encryption == null) {
        throw const BackupFormatException(
          'Password-protected backup has no encryption metadata.',
        );
      }
      if (protection == BackupProtection.none) {
        if (encryption != null) {
          throw const BackupFormatException(
            'Unprotected backup contains encryption metadata.',
          );
        }
        _validateSqlitePayload(payload);
      }

      return _ParsedBackup(
        inspection: BackupInspection(
          formatVersion: formatVersion,
          createdAt: createdAt.toUtc(),
          schemaVersion: schemaVersion,
          storageProfile: storageProfile,
          protection: protection,
          payloadLength: payloadLength,
          payloadSha256: expectedHash,
        ),
        payload: payload,
        encryption: encryption,
      );
    } on BackupFormatException {
      rethrow;
    } on BackupIntegrityException {
      rethrow;
    } on FormatException catch (error) {
      throw BackupFormatException('Malformed backup: ${error.message}');
    } on TypeError {
      throw const BackupFormatException('Malformed backup fields.');
    }
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  Future<String> _sha256Hex(List<int> bytes) async {
    final hash = await Sha256().hash(bytes);
    final buffer = StringBuffer();
    for (final byte in hash.bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  void _validateSqlitePayload(List<int> bytes) {
    if (bytes.length < _sqliteHeader.length) {
      throw const BackupFormatException('Payload is not a SQLite database.');
    }
    for (var index = 0; index < _sqliteHeader.length; index += 1) {
      if (bytes[index] != _sqliteHeader[index]) {
        throw const BackupFormatException('Payload is not a SQLite database.');
      }
    }
  }

  static void _validateKdfParameters({
    required int memory,
    required int iterations,
    required int parallelism,
    required int hashLength,
  }) {
    if (memory < _minimumArgon2Memory || memory > _maximumArgon2Memory) {
      throw const BackupFormatException('Unsupported Argon2 memory cost.');
    }
    if (iterations < 1 || iterations > _maximumArgon2Iterations) {
      throw const BackupFormatException('Unsupported Argon2 iteration count.');
    }
    if (parallelism < 1 || parallelism > _maximumArgon2Parallelism) {
      throw const BackupFormatException('Unsupported Argon2 parallelism.');
    }
    if (hashLength != _keyLength) {
      throw const BackupFormatException('Unsupported derived-key length.');
    }
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw BackupFormatException('Missing or invalid $key.');
    }
    return value;
  }

  static int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int) {
      throw BackupFormatException('Missing or invalid $key.');
    }
    return value;
  }

  static Uint8List _decodeBase64Field(Map<String, dynamic> json, String key) {
    final value = _requiredString(json, key);
    return Uint8List.fromList(base64Decode(value));
  }
}

final class _ParsedBackup {
  const _ParsedBackup({
    required this.inspection,
    required this.payload,
    required this.encryption,
  });

  final BackupInspection inspection;
  final Uint8List payload;
  final Map<String, dynamic>? encryption;
}
