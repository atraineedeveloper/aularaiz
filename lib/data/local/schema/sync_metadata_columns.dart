import 'package:drift/drift.dart';

/// Local metadata required by the cross-device sync engine.
///
/// These columns are nullable during the first sync-metadata migration so
/// existing classroom data can be upgraded without inventing inaccurate edit
/// history. New write paths will progressively start populating them before
/// the record-level sync engine is enabled.
mixin SyncMetadataColumns on Table {
  late final createdAt = dateTime().nullable()();
  late final updatedAt = dateTime().nullable()();
  late final deletedAt = dateTime().nullable()();
  late final updatedByDeviceId = text().nullable()();
}
