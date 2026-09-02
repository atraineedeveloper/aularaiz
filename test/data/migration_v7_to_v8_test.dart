import 'dart:io';

import 'package:aularaiz/application/teacher/save_teacher_profile.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_teacher_profile_repository.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aularaiz-migration-');
    file = File('${directory.path}${Platform.pathSeparator}db.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'migrates a populated v7 database to v8 without losing existing data',
    () async {
      final initial = AppDatabase.forTesting(NativeDatabase(file));
      await initial.customSelect('SELECT 1').getSingle();
      await _seedWorkspaceData(initial);
      await initial.close();

      _downgradeToV7Shape(file.path);

      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      await upgraded.customSelect('SELECT 1').getSingle();

      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 8);

      final schoolColumns = await _columnNames(upgraded, 'schools');
      expect(
        schoolColumns,
        containsAll(<String>[
          'supervisor_name',
          'leadership_name',
          'leadership_role',
        ]),
      );
      final groupColumns = await _columnNames(upgraded, 'teaching_groups');
      expect(groupColumns, contains('teaching_role'));

      // The new teacher profile table works after migration.
      final profileRepository = DriftTeacherProfileRepository(upgraded);
      expect(await profileRepository.load(), isNull);
      await SaveTeacherProfile(repository: profileRepository)(
        fullName: 'María Pérez López',
      );
      expect((await profileRepository.load())?.fullName, 'María Pérez López');

      // Existing schools, groups, contract dates, students, enrollments and
      // attendance are all preserved.
      expect(await _count(upgraded, 'SELECT COUNT(*) AS n FROM schools'), 1);
      expect(
        await _count(upgraded, 'SELECT COUNT(*) AS n FROM teaching_groups'),
        1,
      );
      expect(
        await _count(
          upgraded,
          'SELECT COUNT(*) AS n FROM teaching_groups '
          'WHERE contract_starts_on IS NOT NULL '
          'AND contract_ends_on IS NOT NULL',
        ),
        1,
      );
      expect(
        await _count(upgraded, 'SELECT COUNT(*) AS n FROM group_grades'),
        2,
      );
      expect(await _count(upgraded, 'SELECT COUNT(*) AS n FROM students'), 1);
      expect(
        await _count(upgraded, 'SELECT COUNT(*) AS n FROM enrollments'),
        1,
      );
      expect(
        await _count(upgraded, 'SELECT COUNT(*) AS n FROM attendance_entries'),
        1,
      );

      final schoolRow = await upgraded
          .customSelect('SELECT name, school_zone, school_sector FROM schools')
          .getSingle();
      expect(schoolRow.read<String>('name'), 'Primaria Histórica');
      expect(schoolRow.read<String>('school_zone'), 'Zona 045');
      expect(schoolRow.read<String>('school_sector'), 'Sector 12');
    },
  );

  test(
    'migration tolerates partially applied v8 tables and columns',
    () async {
      final initial = AppDatabase.forTesting(NativeDatabase(file));
      await initial.customSelect('SELECT 1').getSingle();
      await _seedWorkspaceData(initial);
      await initial.close();

      _downgradeToV7Shape(file.path);

      // Simulate an interrupted v8 migration: the teacher profile table and
      // some (but not all) of the new columns already exist.
      final raw = sqlite3.open(file.path);
      raw.execute(
        'CREATE TABLE teacher_profiles ('
        'id TEXT NOT NULL PRIMARY KEY, '
        'full_name TEXT NOT NULL)',
      );
      raw.execute('ALTER TABLE schools ADD COLUMN supervisor_name TEXT');
      raw.execute('ALTER TABLE teaching_groups ADD COLUMN teaching_role TEXT');
      raw.close();

      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      await upgraded.customSelect('SELECT 1').getSingle();

      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 8);

      expect(await _count(upgraded, 'SELECT COUNT(*) AS n FROM schools'), 1);
      expect(
        await _count(upgraded, 'SELECT COUNT(*) AS n FROM teaching_groups'),
        1,
      );
      expect(await _count(upgraded, 'SELECT COUNT(*) AS n FROM students'), 1);
    },
  );

  test('migration tolerates a fully pre-applied v8 shape', () async {
    final initial = AppDatabase.forTesting(NativeDatabase(file));
    await initial.customSelect('SELECT 1').getSingle();
    await _seedWorkspaceData(initial);
    await initial.close();

    _downgradeToV7Shape(file.path);

    final raw = sqlite3.open(file.path);
    raw.execute(
      'CREATE TABLE teacher_profiles ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'full_name TEXT NOT NULL)',
    );
    raw.execute('ALTER TABLE schools ADD COLUMN supervisor_name TEXT');
    raw.execute('ALTER TABLE schools ADD COLUMN leadership_name TEXT');
    raw.execute('ALTER TABLE schools ADD COLUMN leadership_role TEXT');
    raw.execute('ALTER TABLE teaching_groups ADD COLUMN teaching_role TEXT');
    raw.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);
    await upgraded.customSelect('SELECT 1').getSingle();

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 8);
    expect(await _count(upgraded, 'SELECT COUNT(*) AS n FROM enrollments'), 1);
  });
}

Future<void> _seedWorkspaceData(AppDatabase database) async {
  await database
      .into(database.schools)
      .insert(
        const SchoolsCompanion(
          id: Value('school-1'),
          name: Value('Primaria Histórica'),
          cct: Value('27DPR0000X'),
          organization: Value(SchoolOrganization.complete),
          state: Value('Tabasco'),
          municipality: Value('Balancán'),
          locality: Value('San Elpidio'),
          schoolZone: Value('Zona 045'),
          schoolSector: Value('Sector 12'),
        ),
      );
  await database
      .into(database.schoolYears)
      .insert(
        SchoolYearsCompanion(
          id: const Value('year-1'),
          label: const Value('2026-2027'),
          startsOn: Value(DateTime(2026, 8, 31)),
          endsOn: Value(DateTime(2027, 7, 15)),
        ),
      );
  await database
      .into(database.schoolContexts)
      .insert(
        const SchoolContextsCompanion(
          schoolId: Value('school-1'),
          schoolYearId: Value('year-1'),
        ),
      );
  await database
      .into(database.teachingGroups)
      .insert(
        TeachingGroupsCompanion(
          id: const Value('group-1'),
          schoolId: const Value('school-1'),
          schoolYearId: const Value('year-1'),
          name: const Value('1.º y 2.º A'),
          shift: const Value('Matutino'),
          contractStartsOn: Value(DateTime(2026, 9, 1)),
          contractEndsOn: Value(DateTime(2026, 12, 15)),
        ),
      );
  await database.batch((batch) {
    batch.insert(
      database.groupGrades,
      const GroupGradesCompanion(
        groupId: Value('group-1'),
        grade: Value(PrimaryGrade.first),
      ),
    );
    batch.insert(
      database.groupGrades,
      const GroupGradesCompanion(
        groupId: Value('group-1'),
        grade: Value(PrimaryGrade.second),
      ),
    );
  });
  await database
      .into(database.students)
      .insert(
        const StudentsCompanion(
          id: Value('student-1'),
          givenNames: Value('Ana'),
          firstSurname: Value('López'),
        ),
      );
  await database
      .into(database.enrollments)
      .insert(
        EnrollmentsCompanion(
          id: const Value('enrollment-1'),
          studentId: const Value('student-1'),
          groupId: const Value('group-1'),
          grade: const Value(PrimaryGrade.first),
          listNumber: const Value(7),
          startsOn: Value(DateTime(2026, 9, 1)),
        ),
      );
  await database
      .into(database.attendanceDays)
      .insert(
        AttendanceDaysCompanion(
          id: const Value('day-1'),
          groupId: const Value('group-1'),
          date: Value(DateTime(2026, 9, 2)),
        ),
      );
  await database
      .into(database.attendanceEntries)
      .insert(
        const AttendanceEntriesCompanion(
          attendanceDayId: Value('day-1'),
          studentId: Value('student-1'),
          status: Value(AttendanceStatus.present),
        ),
      );
}

/// Rewinds a current (v8) database file to the exact v7 shape so the
/// 7 -> 8 migration can be exercised against realistic legacy state.
void _downgradeToV7Shape(String path) {
  final raw = sqlite3.open(path);
  try {
    raw.execute('DROP TABLE teacher_profiles');

    // v7 schools: no supervisor/leadership columns.
    raw.execute('''
      CREATE TABLE schools_v7 (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        cct TEXT NULL UNIQUE,
        organization TEXT NOT NULL,
        state TEXT NULL,
        municipality TEXT NULL,
        locality TEXT NULL,
        school_zone TEXT NULL,
        school_sector TEXT NULL
      )
    ''');
    raw.execute('''
      INSERT INTO schools_v7 (id, name, cct, organization, state,
                              municipality, locality, school_zone, school_sector)
      SELECT id, name, cct, organization, state,
             municipality, locality, school_zone, school_sector
      FROM schools
    ''');
    raw.execute('DROP TABLE schools');
    raw.execute('ALTER TABLE schools_v7 RENAME TO schools');

    // v7 teaching_groups: no teaching_role column.
    raw.execute('''
      CREATE TABLE teaching_groups_v7 (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL REFERENCES schools (id) ON DELETE RESTRICT,
        school_year_id TEXT NOT NULL REFERENCES school_years (id)
          ON DELETE RESTRICT,
        name TEXT NOT NULL,
        shift TEXT NULL,
        schedule_start_minutes INTEGER NULL,
        schedule_end_minutes INTEGER NULL,
        contract_starts_on INTEGER NULL,
        contract_ends_on INTEGER NULL,
        CHECK ((schedule_start_minutes IS NULL AND schedule_end_minutes IS NULL)
            OR (schedule_start_minutes IS NOT NULL
                AND schedule_end_minutes IS NOT NULL
                AND schedule_start_minutes >= 0
                AND schedule_start_minutes < 1440
                AND schedule_end_minutes > schedule_start_minutes
                AND schedule_end_minutes < 1440)),
        CHECK ((contract_starts_on IS NULL AND contract_ends_on IS NULL)
            OR (contract_starts_on IS NOT NULL
                AND contract_ends_on IS NOT NULL
                AND contract_ends_on >= contract_starts_on))
      )
    ''');
    raw.execute('''
      INSERT INTO teaching_groups_v7 (id, school_id, school_year_id, name,
                                      shift, schedule_start_minutes,
                                      schedule_end_minutes, contract_starts_on,
                                      contract_ends_on)
      SELECT id, school_id, school_year_id, name, shift,
             schedule_start_minutes, schedule_end_minutes,
             contract_starts_on, contract_ends_on
      FROM teaching_groups
    ''');
    raw.execute('DROP TABLE teaching_groups');
    raw.execute('ALTER TABLE teaching_groups_v7 RENAME TO teaching_groups');

    raw.execute('PRAGMA user_version = 7');
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

