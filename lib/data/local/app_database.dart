import 'package:aularaiz/data/local/schema/schema.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: <Type>[
    Schools,
    SchoolYears,
    TeachingGroups,
    GroupGrades,
    Students,
    Enrollments,
    AttendanceDays,
    AttendanceEntries,
    Projects,
    ProjectGrades,
    Activities,
    ActivityGrades,
    ActivityRoster,
    ActivityEvaluations,
    StudentRecords,
    StudentRecordEntries,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {this.storageProfile});

  factory AppDatabase.forTesting(
    QueryExecutor executor, {
    StorageProfile? storageProfile,
  }) {
    return AppDatabase(executor, storageProfile: storageProfile);
  }

  static const int currentSchemaVersion = 1;

  final StorageProfile? storageProfile;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
