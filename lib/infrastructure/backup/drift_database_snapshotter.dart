import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/contracts/database_snapshotter.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:path_provider/path_provider.dart';

typedef BackupTempDirectoryProvider = Future<Directory> Function();

final class DriftDatabaseSnapshotter implements DatabaseSnapshotter {
  DriftDatabaseSnapshotter({
    required AppDatabase database,
    BackupTempDirectoryProvider tempDirectoryProvider = getTemporaryDirectory,
  }) : _database = database,
       _tempDirectoryProvider = tempDirectoryProvider;

  final AppDatabase _database;
  final BackupTempDirectoryProvider _tempDirectoryProvider;

  static int _sequence = 0;

  @override
  Future<Uint8List> createSnapshot() async {
    final directory = await _tempDirectoryProvider();
    await directory.create(recursive: true);
    final sequence = _sequence++;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final snapshot = File(
      '${directory.path}${Platform.pathSeparator}'
      'aularaiz-snapshot-$pid-$timestamp-$sequence.sqlite',
    );

    await _deleteIfPresent(snapshot);
    try {
      await _database.customStatement('VACUUM INTO ?', <Object?>[
        snapshot.path,
      ]);
      if (!await snapshot.exists()) {
        throw StateError(
          'SQLite did not create the requested backup snapshot.',
        );
      }
      final bytes = await snapshot.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('SQLite created an empty backup snapshot.');
      }
      return bytes;
    } finally {
      await _deleteIfPresent(snapshot);
      await _deleteIfPresent(File('${snapshot.path}-wal'));
      await _deleteIfPresent(File('${snapshot.path}-shm'));
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}
