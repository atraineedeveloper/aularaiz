import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

final class SyncDeviceIdentity {
  const SyncDeviceIdentity({required this.id, required this.name});

  final String id;
  final String name;
}

final class LinkedSyncDevice {
  const LinkedSyncDevice({
    required this.id,
    required this.name,
    required this.lastSeenAtUtc,
    this.lastReceivedBackupCreatedAtUtc,
  });

  final String id;
  final String name;
  final DateTime lastSeenAtUtc;
  final DateTime? lastReceivedBackupCreatedAtUtc;
}

final class SyncDeviceRegistry {
  SyncDeviceRegistry({
    SharedPreferencesAsync? preferences,
    Uuid? uuid,
    String? defaultDeviceName,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _uuid = uuid ?? const Uuid(),
       _defaultDeviceName = defaultDeviceName;

  static const _deviceIdKey = 'sync.device.id.v1';
  static const _deviceNameKey = 'sync.device.name.v1';
  static const _linkedPrefix = 'sync.linked.v1.';

  final SharedPreferencesAsync _preferences;
  final Uuid _uuid;
  final String? _defaultDeviceName;

  Future<SyncDeviceIdentity> identity() async {
    var id = await _preferences.getString(_deviceIdKey);
    if (id == null || id.trim().isEmpty) {
      id = _uuid.v4();
      await _preferences.setString(_deviceIdKey, id);
    }

    var name = await _preferences.getString(_deviceNameKey);
    if (name == null || name.trim().isEmpty) {
      name = _defaultDeviceName ?? _defaultName();
      await _preferences.setString(_deviceNameKey, name);
    }

    return SyncDeviceIdentity(id: id, name: name);
  }

  Future<void> rememberLinkedDevice({
    required String id,
    required String name,
    DateTime? receivedBackupCreatedAtUtc,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return;
    final safeName = name.trim().isEmpty ? 'Dispositivo AulaRaíz' : name.trim();
    final now = DateTime.now().toUtc();
    final key = '$_linkedPrefix$normalizedId';
    final value = [
      safeName,
      now.toIso8601String(),
      receivedBackupCreatedAtUtc?.toUtc().toIso8601String() ?? '',
    ].join('\n');
    await _preferences.setString(key, value);
  }

  Future<LinkedSyncDevice?> linkedDevice(String id) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;
    final value = await _preferences.getString('$_linkedPrefix$normalizedId');
    if (value == null || value.trim().isEmpty) return null;
    return _decodeLinkedDevice(normalizedId, value);
  }

  Future<List<LinkedSyncDevice>> listLinkedDevices() async {
    final keys = await _preferences.getKeys();
    final devices = <LinkedSyncDevice>[];
    for (final key in keys) {
      if (!key.startsWith(_linkedPrefix)) continue;
      final id = key.substring(_linkedPrefix.length);
      final value = await _preferences.getString(key);
      if (value == null) continue;
      final device = _decodeLinkedDevice(id, value);
      if (device != null) devices.add(device);
    }
    devices.sort(
      (left, right) => right.lastSeenAtUtc.compareTo(left.lastSeenAtUtc),
    );
    return devices;
  }

  LinkedSyncDevice? _decodeLinkedDevice(String id, String value) {
    final parts = value.split('\n');
    if (parts.length < 2) return null;
    final name = parts[0].trim().isEmpty
        ? 'Dispositivo AulaRaíz'
        : parts[0].trim();
    final lastSeenAtUtc = DateTime.tryParse(parts[1])?.toUtc();
    if (lastSeenAtUtc == null) return null;
    final lastReceived = parts.length >= 3 && parts[2].trim().isNotEmpty
        ? DateTime.tryParse(parts[2])?.toUtc()
        : null;
    return LinkedSyncDevice(
      id: id,
      name: name,
      lastSeenAtUtc: lastSeenAtUtc,
      lastReceivedBackupCreatedAtUtc: lastReceived,
    );
  }

  String _defaultName() {
    try {
      final hostname = Platform.localHostname.trim();
      if (hostname.isNotEmpty) return hostname;
    } on Object {
      // A friendly fallback is enough; identity remains stable through id.
    }
    return 'Dispositivo AulaRaíz';
  }
}
