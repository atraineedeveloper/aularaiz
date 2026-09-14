import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

typedef BackupSummaryTempDirectoryProvider = Future<Directory> Function();

final class BackupContentSummaryReader {
  const BackupContentSummaryReader({
    BackupSummaryTempDirectoryProvider tempDirectoryProvider =
        getTemporaryDirectory,
  }) : _tempDirectoryProvider = tempDirectoryProvider;

  final BackupSummaryTempDirectoryProvider _tempDirectoryProvider;

  static int _sequence = 0;

  Future<BackupContentSummary> read(Uint8List databaseBytes) async {
    final directory = await _tempDirectoryProvider();
    await directory.create(recursive: true);
    final sequence = _sequence++;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'aularaiz-summary-$pid-$timestamp-$sequence.sqlite',
    );

    try {
      await file.writeAsBytes(databaseBytes, flush: true);
      final database = sqlite3.open(file.path);
      try {
        return BackupContentSummary(
          schools: _count(database, 'schools'),
          schoolYears: _count(database, 'school_years'),
          groups: _count(database, 'teaching_groups'),
          students: _count(database, 'students'),
          attendanceDays: _count(database, 'attendance_days'),
          projects: _count(database, 'projects'),
          activities: _count(database, 'activities'),
          evaluations: _count(database, 'activity_evaluations'),
          literacyAssessments: _count(database, 'literacy_assessments'),
          schoolNames: _schoolNames(database),
        );
      } finally {
        database.close();
      }
    } finally {
      await _deleteIfPresent(file);
      await _deleteIfPresent(File('${file.path}-wal'));
      await _deleteIfPresent(File('${file.path}-shm'));
    }
  }

  int _count(Database database, String table) {
    if (!_tableExists(database, table)) return 0;
    final result = database.select('SELECT COUNT(*) AS total FROM $table');
    return result.first['total'] as int;
  }

  List<String> _schoolNames(Database database) {
    if (!_tableExists(database, 'schools')) return const <String>[];
    final rows = database.select(
      'SELECT name FROM schools ORDER BY name COLLATE NOCASE LIMIT 3',
    );
    return rows
        .map((row) => row['name'])
        .whereType<String>()
        .where((name) => name.trim().isNotEmpty)
        .toList(growable: false);
  }

  bool _tableExists(Database database, String table) {
    final result = database.select(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      <Object?>[table],
    );
    return result.isNotEmpty;
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}
