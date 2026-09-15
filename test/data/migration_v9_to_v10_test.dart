import 'dart:io';

import 'package:aularaiz/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aularaiz-v10-');
    file = File('${directory.path}${Platform.pathSeparator}db.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('migration v9 to v10 adds sync metadata without losing data', () async {
    final initial = AppDatabase.forTesting(NativeDatabase(file));
    await initial.customSelect('SELECT 1').getSingle();
    await initial
        .into(initial.students)
        .insert(
          StudentsCompanion.insert(
            id: 'student-1',
            givenNames: 'Ana',
            firstSurname: 'López',
          ),
        );
    await initial.close();

    _simulatePartiallyAppliedV9(file.path);

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.customSelect('SELECT 1').getSingle();

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), AppDatabase.currentSchemaVersion);
    expect(await _count(upgraded, 'SELECT COUNT(*) AS n FROM students'), 1);

    final studentColumns = await _columnNames(upgraded, 'students');
    expect(studentColumns, containsAll(_syncColumns));
    final schoolColumns = await _columnNames(upgraded, 'schools');
    expect(schoolColumns, containsAll(_syncColumns));
    final evaluationColumns = await _columnNames(
      upgraded,
      'activity_evaluations',
    );
    expect(evaluationColumns, containsAll(_syncColumns));
  });
}

const _syncColumns = <String>[
  'created_at',
  'updated_at',
  'deleted_at',
  'updated_by_device_id',
];

void _simulatePartiallyAppliedV9(String path) {
  final raw = sqlite3.open(path);
  try {
    for (final table in <String>[
      'students',
      'schools',
      'activity_evaluations',
    ]) {
      for (final column in _syncColumns) {
        raw.execute('ALTER TABLE $table DROP COLUMN $column');
      }
    }
    raw.execute('PRAGMA user_version = 9');
  } finally {
    raw.close();
  }
}

Future<Set<String>> _columnNames(AppDatabase database, String tableName) async {
  final rows = await database
      .customSelect("PRAGMA table_info('$tableName')")
      .get();
  return rows.map((row) => row.read<String>('name')).toSet();
}

Future<int> _count(AppDatabase database, String sql) async {
  final row = await database.customSelect(sql).getSingle();
  return row.read<int>('n');
}
