import 'dart:io';

import 'package:aularaiz/data/local/storage_layout.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/restore_staging_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending restore state survives settings widget recreation', () async {
    final directory = await Directory.systemTemp.createTemp(
      'aularaiz-pending-restore-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final service = RestoreStagingService(
      profile: StorageProfile.production,
      currentSchemaVersion: 1,
      directoryProvider: () async => directory,
    );
    final layout = await AulaRaizStorageLayout.resolve(
      StorageProfile.production,
      directoryProvider: () async => directory,
    );

    expect(await service.hasPendingRequest(), isFalse);

    await layout.restoreMarkerFile.writeAsString('{}', flush: true);

    expect(await service.hasPendingRequest(), isTrue);
  });
}
