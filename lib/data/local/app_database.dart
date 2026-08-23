import 'package:aularaiz/data/local/database_connection_stub.dart'
    if (dart.library.ui) 'package:aularaiz/data/local/database_connection.dart';
import 'package:aularaiz/data/local/schema/schema.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
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
    SchoolContexts,
    TeachingGroups,
    GroupGrades,
    Students,
    Enrollments,
    AttendanceDays,
    AttendanceEntries,
    Projects,
    ProjectGrades,
    ProjectFormativeFields,
    ProjectArticulatingAxes,
    Activities,
    ActivityGrades,
    ActivityFormativeFields,
    ActivityRoster,
    ActivityEvaluations,
    StudentRecords,
    StudentRecordEntries,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor, {this.storageProfile});

  factory AppDatabase.production() => AppDatabase(
    openAulaRaizConnection(StorageProfile.production),
    storageProfile: StorageProfile.production,
  );

  factory AppDatabase.demo() => AppDatabase(
    openAulaRaizConnection(StorageProfile.demo),
    storageProfile: StorageProfile.demo,
  );

  factory AppDatabase.forTesting(
    QueryExecutor executor, {
    StorageProfile? storageProfile,
  }) => AppDatabase(executor, storageProfile: storageProfile);

  static const int currentSchemaVersion = 3;

  final StorageProfile? storageProfile;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.createTable(schoolContexts);
        await migrator.createTable(projectFormativeFields);
        await migrator.createTable(projectArticulatingAxes);
        await migrator.createTable(activityFormativeFields);
        await customStatement('''
          INSERT OR IGNORE INTO school_contexts (school_id, school_year_id)
          SELECT s.id,
                 COALESCE(
                   (SELECT tg.school_year_id FROM teaching_groups tg WHERE tg.school_id = s.id LIMIT 1),
                   (SELECT sy.id FROM school_years sy ORDER BY sy.starts_on DESC LIMIT 1)
                 )
          FROM schools s
          WHERE EXISTS (SELECT 1 FROM school_years)
        ''');
        await customStatement('''
          INSERT OR IGNORE INTO project_formative_fields (project_id, formative_field)
          SELECT id, formative_field FROM projects
        ''');
        await customStatement('''
          INSERT OR IGNORE INTO activity_formative_fields (activity_id, formative_field)
          SELECT a.id, p.formative_field
          FROM activities a INNER JOIN projects p ON p.id = a.project_id
        ''');
      }
      if (from < 3) {
        await migrator.addColumn(activities, activities.identifier);
        await migrator.addColumn(activities, activities.occursOn);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
