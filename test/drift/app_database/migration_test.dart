// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by alterating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  // TODO: This generated template shows how these tests could be written. Adopt
  // it to your own needs when testing migrations with data integrity.
  test('migration from v1 to v2 does not corrupt data', () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    // TODO: Fill these lists
    final oldSchoolsData = <v1.SchoolsData>[];
    final expectedNewSchoolsData = <v2.SchoolsData>[];

    final oldSchoolYearsData = <v1.SchoolYearsData>[];
    final expectedNewSchoolYearsData = <v2.SchoolYearsData>[];

    final oldTeachingGroupsData = <v1.TeachingGroupsData>[];
    final expectedNewTeachingGroupsData = <v2.TeachingGroupsData>[];

    final oldGroupGradesData = <v1.GroupGradesData>[];
    final expectedNewGroupGradesData = <v2.GroupGradesData>[];

    final oldStudentsData = <v1.StudentsData>[];
    final expectedNewStudentsData = <v2.StudentsData>[];

    final oldEnrollmentsData = <v1.EnrollmentsData>[];
    final expectedNewEnrollmentsData = <v2.EnrollmentsData>[];

    final oldAttendanceDaysData = <v1.AttendanceDaysData>[];
    final expectedNewAttendanceDaysData = <v2.AttendanceDaysData>[];

    final oldAttendanceEntriesData = <v1.AttendanceEntriesData>[];
    final expectedNewAttendanceEntriesData = <v2.AttendanceEntriesData>[];

    final oldProjectsData = <v1.ProjectsData>[];
    final expectedNewProjectsData = <v2.ProjectsData>[];

    final oldProjectGradesData = <v1.ProjectGradesData>[];
    final expectedNewProjectGradesData = <v2.ProjectGradesData>[];

    final oldActivitiesData = <v1.ActivitiesData>[];
    final expectedNewActivitiesData = <v2.ActivitiesData>[];

    final oldActivityGradesData = <v1.ActivityGradesData>[];
    final expectedNewActivityGradesData = <v2.ActivityGradesData>[];

    final oldActivityRosterData = <v1.ActivityRosterData>[];
    final expectedNewActivityRosterData = <v2.ActivityRosterData>[];

    final oldActivityEvaluationsData = <v1.ActivityEvaluationsData>[];
    final expectedNewActivityEvaluationsData = <v2.ActivityEvaluationsData>[];

    final oldStudentRecordsData = <v1.StudentRecordsData>[];
    final expectedNewStudentRecordsData = <v2.StudentRecordsData>[];

    final oldStudentRecordEntriesData = <v1.StudentRecordEntriesData>[];
    final expectedNewStudentRecordEntriesData = <v2.StudentRecordEntriesData>[];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.schools, oldSchoolsData);
        batch.insertAll(oldDb.schoolYears, oldSchoolYearsData);
        batch.insertAll(oldDb.teachingGroups, oldTeachingGroupsData);
        batch.insertAll(oldDb.groupGrades, oldGroupGradesData);
        batch.insertAll(oldDb.students, oldStudentsData);
        batch.insertAll(oldDb.enrollments, oldEnrollmentsData);
        batch.insertAll(oldDb.attendanceDays, oldAttendanceDaysData);
        batch.insertAll(oldDb.attendanceEntries, oldAttendanceEntriesData);
        batch.insertAll(oldDb.projects, oldProjectsData);
        batch.insertAll(oldDb.projectGrades, oldProjectGradesData);
        batch.insertAll(oldDb.activities, oldActivitiesData);
        batch.insertAll(oldDb.activityGrades, oldActivityGradesData);
        batch.insertAll(oldDb.activityRoster, oldActivityRosterData);
        batch.insertAll(oldDb.activityEvaluations, oldActivityEvaluationsData);
        batch.insertAll(oldDb.studentRecords, oldStudentRecordsData);
        batch.insertAll(
          oldDb.studentRecordEntries,
          oldStudentRecordEntriesData,
        );
      },
      validateItems: (newDb) async {
        expect(expectedNewSchoolsData, await newDb.select(newDb.schools).get());
        expect(
          expectedNewSchoolYearsData,
          await newDb.select(newDb.schoolYears).get(),
        );
        expect(
          expectedNewTeachingGroupsData,
          await newDb.select(newDb.teachingGroups).get(),
        );
        expect(
          expectedNewGroupGradesData,
          await newDb.select(newDb.groupGrades).get(),
        );
        expect(
          expectedNewStudentsData,
          await newDb.select(newDb.students).get(),
        );
        expect(
          expectedNewEnrollmentsData,
          await newDb.select(newDb.enrollments).get(),
        );
        expect(
          expectedNewAttendanceDaysData,
          await newDb.select(newDb.attendanceDays).get(),
        );
        expect(
          expectedNewAttendanceEntriesData,
          await newDb.select(newDb.attendanceEntries).get(),
        );
        expect(
          expectedNewProjectsData,
          await newDb.select(newDb.projects).get(),
        );
        expect(
          expectedNewProjectGradesData,
          await newDb.select(newDb.projectGrades).get(),
        );
        expect(
          expectedNewActivitiesData,
          await newDb.select(newDb.activities).get(),
        );
        expect(
          expectedNewActivityGradesData,
          await newDb.select(newDb.activityGrades).get(),
        );
        expect(
          expectedNewActivityRosterData,
          await newDb.select(newDb.activityRoster).get(),
        );
        expect(
          expectedNewActivityEvaluationsData,
          await newDb.select(newDb.activityEvaluations).get(),
        );
        expect(
          expectedNewStudentRecordsData,
          await newDb.select(newDb.studentRecords).get(),
        );
        expect(
          expectedNewStudentRecordEntriesData,
          await newDb.select(newDb.studentRecordEntries).get(),
        );
      },
    );
  });
}
