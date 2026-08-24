import 'package:aularaiz/data/local/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'current schema contains the primary baseline and later additions',
    () async {
      final rows = await database
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
          )
          .get();
      final tableNames = rows.map((row) => row.read<String>('name')).toSet();

      expect(
        tableNames,
        containsAll(<String>[
          'schools',
          'school_years',
          'school_contexts',
          'teaching_groups',
          'group_grades',
          'students',
          'enrollments',
          'attendance_days',
          'attendance_entries',
          'projects',
          'project_grades',
          'project_formative_fields',
          'project_articulating_axes',
          'activities',
          'activity_grades',
          'activity_formative_fields',
          'activity_roster',
          'activity_evaluations',
          'student_records',
          'student_record_entries',
        ]),
      );
    },
  );

  test(
    'fresh database publishes schema version 5 with foreign keys on',
    () async {
      final versionRow = await database
          .customSelect('PRAGMA user_version')
          .getSingle();
      final foreignKeyRow = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();

      expect(database.schemaVersion, AppDatabase.currentSchemaVersion);
      expect(database.schemaVersion, 5);
      expect(versionRow.read<int>('user_version'), 5);
      expect(foreignKeyRow.read<int>('foreign_keys'), 1);
    },
  );
}
