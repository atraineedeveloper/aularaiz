import 'dart:io';

import 'package:aularaiz/data/local/storage_layout.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classroom data survives removal of separate program files', () async {
    final root = await Directory.systemTemp.createTemp(
      'aularaiz-lifecycle-test-',
    );

    try {
      final programDirectory = Directory(
        '${root.path}${Platform.pathSeparator}program',
      );
      final dataDirectory = Directory(
        '${root.path}${Platform.pathSeparator}support',
      );
      await programDirectory.create(recursive: true);
      await dataDirectory.create(recursive: true);
      await File(
        '${programDirectory.path}${Platform.pathSeparator}aularaiz.exe',
      ).writeAsString('program');

      final layout = await AulaRaizStorageLayout.resolve(
        StorageProfile.production,
        directoryProvider: () async => dataDirectory,
      );
      await layout.databaseFile.writeAsString('classroom-data');

      expect(
        layout.databaseFile.path.startsWith(programDirectory.path),
        isFalse,
      );

      await programDirectory.delete(recursive: true);

      expect(await layout.databaseFile.exists(), isTrue);
      expect(await layout.databaseFile.readAsString(), 'classroom-data');
    } finally {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });
}
