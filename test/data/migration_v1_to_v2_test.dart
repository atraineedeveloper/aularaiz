import 'package:aularaiz/data/local/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('v1 to v2 migration preserves legacy data and backfills relations', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    // Open the current schema, then remove only the v2-only tables. The
    // remaining tables are the v1 shape this migration upgrades from.
    await database.customSelect('SELECT 1').get();

    await database.customStatement('''
      INSERT INTO schools
        (id, name, cct, organization, state, municipality, locality)
      VALUES
        ('school-1', 'Primaria de prueba', '27DPR0000X', 'complete',
         'Tabasco', 'Balancán', 'San Elpidio')
    ''');
    await database.customStatement('''
      INSERT INTO school_years (id, label, starts_on, ends_on)
      VALUES ('year-1', '2026-2027', 1788134400000, 1815091200000)
    ''');
    await database.customStatement('''
      INSERT INTO teaching_groups
        (id, school_id, school_year_id, name)
      VALUES ('group-1', 'school-1', 'year-1', '3.º A')
    ''');
    await database.customStatement('''
      INSERT INTO projects
        (id, group_id, title, lifecycle, methodology, formative_field)
      VALUES
        ('project-1', 'group-1', 'Nuestra comunidad', 'inProgress',
         'communityProjects', 'languages')
    ''');
    await database.customStatement('''
      INSERT INTO activities (id, project_id, title)
      VALUES ('activity-1', 'project-1', 'Entrevista comunitaria')
    ''');
    await database.customStatement('''
      INSERT INTO students (id, given_names, first_surname)
      VALUES ('student-1', 'Ana', 'López')
    ''');
    await database.customStatement('''
      INSERT INTO student_record_entries
        (id, student_id, kind, occurred_at, text)
      VALUES
        ('entry-1', 'student-1', 'observation', 1788134400000,
         'Nota histórica preservada')
    ''');

    await database.customStatement('DROP TABLE activity_formative_fields');
    await database.customStatement('DROP TABLE project_articulating_axes');
    await database.customStatement('DROP TABLE project_formative_fields');
    await database.customStatement('DROP TABLE school_contexts');

    final onUpgrade = database.migration.onUpgrade;
    expect(onUpgrade, isNotNull);
    await onUpgrade!(Migrator(database), 1, 2);

    final contextRows = await database.customSelect('''
      SELECT school_id, school_year_id FROM school_contexts
      WHERE school_id = 'school-1'
    ''').get();
    expect(contextRows, hasLength(1));
    expect(contextRows.single.read<String>('school_year_id'), 'year-1');

    final projectFields = await database.customSelect('''
      SELECT formative_field FROM project_formative_fields
      WHERE project_id = 'project-1'
    ''').get();
    expect(projectFields, hasLength(1));
    expect(projectFields.single.read<String>('formative_field'), 'languages');

    final activityFields = await database.customSelect('''
      SELECT formative_field FROM activity_formative_fields
      WHERE activity_id = 'activity-1'
    ''').get();
    expect(activityFields, hasLength(1));
    expect(activityFields.single.read<String>('formative_field'), 'languages');

    final axes = await database.customSelect('''
      SELECT articulating_axis FROM project_articulating_axes
      WHERE project_id = 'project-1'
    ''').get();
    expect(axes, isEmpty);

    final legacyProject = await database.customSelect('''
      SELECT title, formative_field FROM projects
      WHERE id = 'project-1'
    ''').getSingle();
    expect(legacyProject.read<String>('title'), 'Nuestra comunidad');
    expect(legacyProject.read<String>('formative_field'), 'languages');

    final legacyNote = await database.customSelect('''
      SELECT text FROM student_record_entries WHERE id = 'entry-1'
    ''').getSingle();
    expect(legacyNote.read<String>('text'), 'Nota histórica preservada');
  });
}
