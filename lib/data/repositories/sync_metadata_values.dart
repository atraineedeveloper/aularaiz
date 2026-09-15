import 'package:drift/drift.dart';

typedef SyncDeviceIdProvider = Future<String?> Function();

/// Timestamp values used by local writes that can later participate in
/// record-level device synchronization.
final class SyncMetadataValues {
  SyncMetadataValues._();

  static DateTime now() => DateTime.now().toUtc();

  static Value<DateTime> created(DateTime timestamp) => Value(timestamp);

  static Value<DateTime> updated(DateTime timestamp) => Value(timestamp);

  static Value<DateTime> deleted(DateTime timestamp) => Value(timestamp);

  static Future<Value<String?>> deviceId(SyncDeviceIdProvider? provider) async {
    final id = await provider?.call();
    final normalized = id?.trim();
    return Value(normalized == null || normalized.isEmpty ? null : normalized);
  }
}
