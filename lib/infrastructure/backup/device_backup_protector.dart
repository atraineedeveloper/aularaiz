import 'dart:convert';
import 'dart:typed_data';

import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class BackupEncryptionKeyStore {
  Future<Uint8List?> readKey();

  Future<void> writeKey(Uint8List keyBytes);
}

final class SecureBackupEncryptionKeyStore implements BackupEncryptionKeyStore {
  const SecureBackupEncryptionKeyStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  static const String _storageKey = 'aularaiz.backup.device-key.v1';
  static const int keyLength = 32;

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> readKey() async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null) return null;

    try {
      final decoded = base64Decode(encoded);
      if (decoded.length != keyLength) {
        throw const BackupProtectionException(
          BackupProtectionProblem.keyUnavailable,
          'Stored backup encryption key has an invalid length.',
        );
      }
      return Uint8List.fromList(decoded);
    } on BackupProtectionException {
      rethrow;
    } on Object {
      throw const BackupProtectionException(
        BackupProtectionProblem.keyUnavailable,
        'Stored backup encryption key could not be decoded.',
      );
    }
  }

  @override
  Future<void> writeKey(Uint8List keyBytes) async {
    if (keyBytes.length != keyLength) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes.length',
        'Backup encryption keys must be 32 bytes.',
      );
    }
    await _storage.write(key: _storageKey, value: base64Encode(keyBytes));
  }
}

final class DeviceBackupProtector implements BackupProtector {
  DeviceBackupProtector({
    required BackupEncryptionKeyStore keyStore,
    AesGcm? algorithm,
  }) : _keyStore = keyStore,
       _algorithm = algorithm ?? AesGcm.with256bits();

  static const int currentEnvelopeVersion = 1;
  static const String protectionName = 'aes-256-gcm-device-v1';
  static const int _headerLengthBytes = 4;
  static const int _maxHeaderBytes = 64 * 1024;
  static final Uint8List _magic = Uint8List.fromList(
    utf8.encode('AULARAIZ_PROTECTED\n'),
  );

  final BackupEncryptionKeyStore _keyStore;
  final AesGcm _algorithm;

  @override
  Future<Uint8List> protect(Uint8List clearBytes) async {
    if (_startsWith(clearBytes, _magic)) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Backup payload is already protected.',
      );
    }

    final keyBytes = await _getOrCreateKey();
    final nonce = _algorithm.newNonce();
    final secretBox = await _algorithm.encrypt(
      clearBytes,
      secretKey: SecretKeyData(keyBytes),
      nonce: nonce,
    );
    final header = <String, Object?>{
      'envelopeVersion': currentEnvelopeVersion,
      'protection': protectionName,
      'keyId': _keyId(keyBytes),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
      'cipherLength': secretBox.cipherText.length,
    };
    final headerBytes = utf8.encode(jsonEncode(header));
    if (headerBytes.length > _maxHeaderBytes) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Protected backup header is unexpectedly large.',
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
      return Uint8List.fromList(protectedOrLegacyBytes);
    }

    final minimumLength = _magic.length + _headerLengthBytes;
    if (protectedOrLegacyBytes.length < minimumLength) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Protected backup is too short to contain a header.',
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
        'Protected backup header length is invalid.',
      );
    }

    final headerOffset = _magic.length + _headerLengthBytes;
    final cipherOffset = headerOffset + headerLength;
    if (cipherOffset > protectedOrLegacyBytes.length) {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Protected backup ended before the header was complete.',
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
        'Protected backup envelope version $version is not supported.',
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

    final keyBytes = await _keyStore.readKey();
    if (keyBytes == null) {
      throw const BackupProtectionException(
        BackupProtectionProblem.keyUnavailable,
        'This installation does not have a backup encryption key.',
      );
    }
    if (keyBytes.length != SecureBackupEncryptionKeyStore.keyLength) {
      throw const BackupProtectionException(
        BackupProtectionProblem.keyUnavailable,
        'Backup encryption key has an invalid length.',
      );
    }

    final expectedKeyId = _requiredString(header, 'keyId');
    if (_keyId(keyBytes) != expectedKeyId) {
      throw const BackupProtectionException(
        BackupProtectionProblem.keyMismatch,
        'Backup was encrypted by a different AulaRaíz installation.',
      );
    }

    late final Uint8List nonce;
    late final Uint8List mac;
    try {
      nonce = Uint8List.fromList(
        base64Decode(_requiredString(header, 'nonce')),
      );
      mac = Uint8List.fromList(base64Decode(_requiredString(header, 'mac')));
    } on BackupProtectionException {
      rethrow;
    } on Object {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Protected backup nonce or MAC is invalid.',
      );
    }

    try {
      final clearBytes = await _algorithm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKeyData(keyBytes),
      );
      return Uint8List.fromList(clearBytes);
    } on SecretBoxAuthenticationError {
      throw const BackupProtectionException(
        BackupProtectionProblem.authenticationFailed,
        'Encrypted backup authentication failed.',
      );
    } on ArgumentError {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Protected backup cryptographic parameters are invalid.',
      );
    }
  }

  Future<Uint8List> _getOrCreateKey() async {
    final existing = await _keyStore.readKey();
    if (existing != null) {
      if (existing.length != SecureBackupEncryptionKeyStore.keyLength) {
        throw const BackupProtectionException(
          BackupProtectionProblem.keyUnavailable,
          'Backup encryption key has an invalid length.',
        );
      }
      return existing;
    }

    final generated = await _algorithm.newSecretKey();
    final bytes = Uint8List.fromList(await generated.extractBytes());
    await _keyStore.writeKey(bytes);
    return bytes;
  }

  String _keyId(Uint8List keyBytes) =>
      hashes.sha256.convert(keyBytes).toString().substring(0, 32);

  Map<String, Object?> _decodeHeader(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const BackupProtectionException(
          BackupProtectionProblem.invalidEnvelope,
          'Protected backup header must be a JSON object.',
        );
      }
      return Map<String, Object?>.from(decoded);
    } on BackupProtectionException {
      rethrow;
    } on Object {
      throw const BackupProtectionException(
        BackupProtectionProblem.invalidEnvelope,
        'Protected backup header is not valid JSON.',
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
}
