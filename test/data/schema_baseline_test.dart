import 'package:aularaiz/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema v2 opens and matches the generated Drift schema', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await database.customSelect('SELECT 1').getSingle();

    expect(database.schemaVersion, AppDatabase.currentSchemaVersion);
    expect(database.schemaVersion, 2);
    await database.validateDatabaseSchema();

    final foreignKeys = await database
        .customSelect('PRAGMA foreign_keys')
        .getSingle();
    expect(foreignKeys.read<int>('foreign_keys'), 1);
  });
}
