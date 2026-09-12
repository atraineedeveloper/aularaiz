import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:cryptography/cryptography.dart';

final class PortableBackupProtector implements BackupProtector {
  PortableBackupProtector({
    required String transferCode,
    AesGcm? cipher,
    Pbkdf2? keyDerivation,
    Random? random,
  }) : _transferCode = _normalizeCode(transferCode),
       _cipher = cipher ?? AesGcm.with256bits(),
       _keyDerivation =
           keyDerivation ??
           Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 210000, bits: 256),
       _random = random ?? Random.secure() {
    if (_transferCode.length < 8) {
      throw ArgumentError.value(
        transferCode,
        'transferCode',
        'Transfer code must contain at least 8 characters.',
      );
    }
  }

  static const int currentEnvelopeVersion = 1;
  static const String protectionName = 'aes-256-gcm-portable-v1';
  static const int _headerLengthBytes = 4;
  static const int _maxHeaderBytes = 64 * 1024;
  static const int _saltLength = 16;
  static final Uint8List _magic = Uint8List.fromList(
    utf8.encode('AULARAIZ_PORTABLE\n'),
  );

  final String _transferCode;
  final AesGcm _cipher;
  final Pbkdf2 _keyDerivation;
  final Random _random;

  @override
  Future<Uint8List> protect(Uint8List clearBytes) async {
    if (_startsWith(clearBytes, _magic)) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Backup payload is already portable-protected.',
      );
    }

    final salt = _randomBytes(_saltLength);
    final keyBytes = await _deriveKey(salt);
    final nonce = _cipher.newNonce();
    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: SecretKeyData(keyBytes),
      nonce: nonce,
    );
    final header = <String, Object?>{
      'envelopeVersion': currentEnvelopeVersion,
      'protection': protectionName,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _keyDerivation.iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'cipherLength': secretBox.cipherText.length,
    };
    final headerBytes = utf8.encode(jsonEncode(header));
    if (headerBytes.length > _maxHeaderBytes) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Portable backup header is unexpectedly large.',
      );
    }

    final lengthBytes = ByteData(_headerLengthBytes)
      ..setUint32(0, headerBytes.length, Endian.big);
    final builder = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(lengthBytes.buffer.asUint8List())
      ..add(headerBytes)
      ..add(secretBox.cipherText);
    return builder.takeBytes();
  }

  @override
  Future<Uint8List> unprotect(Uint8List protectedOrLegacyBytes) async {
    if (!_startsWith(protectedOrLegacyBytes, _magic)) {
      throw const BackupProtectionException(
        BackupProtectionProblem.unsupportedProtection,
        'File is not an AulaRaiz portable backup.',
      );
    }

    final minimumLength = _magic.length + _headerLengthBytes;
    if (protectedOrLegacyBytes.length < minimumLength) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Portable backup is too short to contain a header.',
      );
    }

    final headerLength = ByteData.sublistView(
      protectedOrLegacyBytes,
      _magic.length,
      _magic.length + _headerLengthBytes,
    ).getUint32(0, Endian.big);
    if (headerLength <= 0 || headerLength > _maxHeaderBytes) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Portable backup header length is invalid.',
      );
    }

    final headerOffset = _magic.length + _headerLengthBytes;
    final cipherOffset = headerOffset + headerLength;
    if (cipherOffset > protectedOrLegacyBytes.length) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Portable backup ended before the header was complete.',
      );
    }

    final header = _decodeHeader(
      Uint8List.fromList(
        protectedOrLegacyBytes.sublist(headerOffset, cipherOffset),
      ),
    );
    final version = _requiredInt(header, 'envelopeVersion');
    if (version != currentEnvelopeVersion) {
      throw BackupProtectionException(
        BackupProtectionProblem.unsupportedProtection,
        'Portable backup envelope version $version is not supported.',
      );
    }
    final protection = _requiredString(header, 'protection');
    if (protection != protectionName) {
      throw BackupProtectionException(
        BackupProtectionProblem.unsupportedProtection,
        'Backup protection $protection is not supported.',
      );
    }

    final cipherText = Uint8List.fromList(
      protectedOrLegacyBytes.sublist(cipherOffset),
    );
    final expectedLength = _requiredInt(header, 'cipherLength');
    if (expectedLength < 0 || cipherText.length != expectedLength) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Encrypted payload length does not match the header.',
      );
    }

    late final Uint8List salt;
    late final Uint8List nonce;
    late final Uint8List mac;
    try {
      salt = Uint8List.fromList(base64Decode(_requiredString(header, 'salt')));
      nonce = Uint8List.fromList(
        base64Decode(_requiredString(header, 'nonce')),
      );
      mac = Uint8List.fromList(base64Decode(_requiredString(header, 'mac')));
    } on BackupProtectionException {
      rethrow;
    } on Object {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Portable backup cryptographic parameters are invalid.',
      );
    }

    try {
      final clearBytes = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKeyData(await _deriveKey(salt)),
      );
      return Uint8List.fromList(clearBytes);
    } on SecretBoxAuthenticationError {
      throw const BackupProtectionException(
        BackupProtectionProblem.authenticationFailed,
        'Transfer code is incorrect or the portable backup was altered.',
      );
    } on ArgumentError {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Portable backup cryptographic parameters are invalid.',
      );
    }
  }

  Future<Uint8List> _deriveKey(Uint8List salt) async {
    final secretKey = await _keyDerivation.deriveKey(
      secretKey: SecretKeyData(utf8.encode(_transferCode)),
      nonce: salt,
    );
    return Uint8List.fromList(await secretKey.extractBytes());
  }

  Uint8List _randomBytes(int length) {
    return Uint8List.fromList(
      List<int>.generate(length, (_) => _random.nextInt(256)),
    );
  }

  Map<String, Object?> _decodeHeader(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BackupProtectionException(
          BackupProtectionProblem.invalidEnvelope,
          'Portable backup header must be a JSON object.',
        );
      }
      return Map<String, Object?>.from(decoded);
    } on BackupProtectionException {
      rethrow;
    } on Object {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Portable backup header is not valid JSON.',
      );
    }
  }

  String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String && value.isNotEmpty) return value;
    throw BackupProtectionException(
      BackupProtectionProblem.invalidEnvelope,
      '$key must be a non-empty string.',
    );
  }

  int _requiredInt(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw BackupProtectionException(
      BackupProtectionProblem.invalidEnvelope,
      '$key must be an integer.',
    );
  }

  bool _startsWith(Uint8List value, Uint8List prefix) {
    if (value.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index += 1) {
      if (value[index] != prefix[index]) return false;
    }
    return true;
  }

  static String _normalizeCode(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}

String generatePortableBackupTransferCode({Random? random}) {
  const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  final source = random ?? Random.secure();
  final raw = List<String>.generate(
    16,
    (_) => alphabet[source.nextInt(alphabet.length)],
  ).join();
  return '${raw.substring(0, 4)}-${raw.substring(4, 8)}-'
      '${raw.substring(8, 12)}-${raw.substring(12, 16)}';
}
