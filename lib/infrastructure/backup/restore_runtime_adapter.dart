import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/drift_database_snapshotter.dart';
import 'package:drift/native.dart';

final class RestoreRuntimeAdapter {
  const RestoreRuntimeAdapter();

  Future<Uint8List> createCurrentSnapshot(StorageProfile profile) async {
    final database = switch (profile) {
      StorageProfile.production => AppDatabase.production(),
      StorageProfile.demo => AppDatabase.demo(),
    };
    try {
      await database.customSelect('SELECT 1').get();
      return DriftDatabaseSnapshotter(database: database).createSnapshot();
    } finally {
      await database.close();
    }
  }

  Future<void> openAndMigrate(File file, StorageProfile profile) async {
    final database = AppDatabase.forTesting(
      NativeDatabase(file),
      storageProfile: profile,
    );
    try {
      await database.customSelect('SELECT 1').get();
    } finally {
      await database.close();
    }
  }
}
