import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/backup/create_backup.dart';
import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_enrollment_batch_writer.dart';
import 'package:aularaiz/application/contracts/student_enrollment_writer.dart';
import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/project/create_activity.dart';
import 'package:aularaiz/application/project/create_project.dart';
import 'package:aularaiz/application/reports/report_projection_builder.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/application/school_setup/start_school_year.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/application/student_import/import_students.dart';
import 'package:aularaiz/application/student_import/student_import_preview_builder.dart';
import 'package:aularaiz/application/student_record/add_student_record_entry.dart';
import 'package:aularaiz/application/student_record/update_student_record.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/core/id/uuid_id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/data/repositories/drift_activity_repository.dart';
import 'package:aularaiz/data/repositories/drift_attendance_repository.dart';
import 'package:aularaiz/data/repositories/drift_enrollment_repository.dart';
import 'package:aularaiz/data/repositories/drift_evaluation_repository.dart';
import 'package:aularaiz/data/repositories/drift_project_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_year_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_enrollment_batch_writer.dart';
import 'package:aularaiz/data/repositories/drift_student_enrollment_writer.dart';
import 'package:aularaiz/data/repositories/drift_student_record_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:aularaiz/infrastructure/backup/backup_restore_gateway.dart';
import 'package:aularaiz/infrastructure/backup/device_backup_protector.dart';
import 'package:aularaiz/infrastructure/backup/drift_database_snapshotter.dart';
import 'package:aularaiz/infrastructure/backup/restore_staging_service.dart';
import 'package:aularaiz/infrastructure/reports/report_publication_service.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class AppDependencies extends StatelessWidget {
  const AppDependencies({
    required this.storageProfile,
    required this.child,
    super.key,
  });

  final StorageProfile storageProfile;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (_) => switch (storageProfile) {
            StorageProfile.production => AppDatabase.production(),
            StorageProfile.demo => AppDatabase.demo(),
          },
          dispose: (_, database) => database.close(),
        ),
        Provider<IdGenerator>(create: (_) => UuidIdGenerator()),
        Provider<SchoolSetupRepository>(
          create: (context) =>
              DriftSchoolSetupRepository(context.read<AppDatabase>()),
        ),
        Provider<SchoolYearRepository>(
          create: (context) =>
              DriftSchoolYearRepository(context.read<AppDatabase>()),
        ),
        Provider<TeachingGroupRepository>(
          create: (context) =>
              DriftTeachingGroupRepository(context.read<AppDatabase>()),
        ),
        Provider<StudentRepository>(
          create: (context) =>
              DriftStudentRepository(context.read<AppDatabase>()),
        ),
        Provider<EnrollmentRepository>(
          create: (context) =>
              DriftEnrollmentRepository(context.read<AppDatabase>()),
        ),
        Provider<AttendanceRepository>(
          create: (context) =>
              DriftAttendanceRepository(context.read<AppDatabase>()),
        ),
        Provider<ProjectRepository>(
          create: (context) =>
              DriftProjectRepository(context.read<AppDatabase>()),
        ),
        Provider<ActivityRepository>(
          create: (context) =>
              DriftActivityRepository(context.read<AppDatabase>()),
        ),
        Provider<EvaluationRepository>(
          create: (context) =>
              DriftEvaluationRepository(context.read<AppDatabase>()),
        ),
        Provider<StudentRecordRepository>(
          create: (context) =>
              DriftStudentRecordRepository(context.read<AppDatabase>()),
        ),
        Provider<StudentEnrollmentWriter>(
          create: (context) =>
              DriftStudentEnrollmentWriter(context.read<AppDatabase>()),
        ),
        Provider<StudentEnrollmentBatchWriter>(
          create: (context) =>
              DriftStudentEnrollmentBatchWriter(context.read<AppDatabase>()),
        ),
        Provider<ReportProjectionBuilder>(
          create: (context) => ReportProjectionBuilder(
            schoolSetupRepository: context.read<SchoolSetupRepository>(),
            enrollmentRepository: context.read<EnrollmentRepository>(),
            studentRepository: context.read<StudentRepository>(),
            attendanceRepository: context.read<AttendanceRepository>(),
            projectRepository: context.read<ProjectRepository>(),
            activityRepository: context.read<ActivityRepository>(),
            evaluationRepository: context.read<EvaluationRepository>(),
            studentRecordRepository: context.read<StudentRecordRepository>(),
          ),
        ),
        Provider<ReportPublicationService>(
          create: (_) => const ReportPublicationService(),
        ),
        Provider<BackupProtector>(
          create: (_) => DeviceBackupProtector(
            keyStore: const SecureBackupEncryptionKeyStore(),
          ),
        ),
        Provider<BackupRestoreGateway>(
          create: (context) => PlatformBackupRestoreGateway(
            createBackup: CreateBackup(
              snapshotter: DriftDatabaseSnapshotter(
                database: context.read<AppDatabase>(),
              ),
              schemaVersion: AppDatabase.currentSchemaVersion,
              storageProfile: storageProfile.name,
              protector: context.read<BackupProtector>(),
            ),
            restoreStagingService: RestoreStagingService(
              profile: storageProfile,
              currentSchemaVersion: AppDatabase.currentSchemaVersion,
              protector: context.read<BackupProtector>(),
            ),
            publicationService: context.read<ReportPublicationService>(),
          ),
        ),
        Provider<CreateInitialSchoolSetup>(
          create: (context) => CreateInitialSchoolSetup(
            repository: context.read<SchoolSetupRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<CreateTeachingGroup>(
          create: (context) => CreateTeachingGroup(
            repository: context.read<TeachingGroupRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<CreateInitialWorkspace>(
          create: (context) => CreateInitialWorkspace(
            createSchoolSetup: context.read<CreateInitialSchoolSetup>(),
            createTeachingGroup: context.read<CreateTeachingGroup>(),
            schoolSetupRepository: context.read<SchoolSetupRepository>(),
          ),
        ),
        Provider<SchoolYearStarterRepository>(
          create: (context) =>
              DriftSchoolSetupRepository(context.read<AppDatabase>()),
        ),
        Provider<StartSchoolYear>(
          create: (context) => StartSchoolYear(
            setupRepository: context.read<SchoolSetupRepository>(),
            starterRepository: context.read<SchoolYearStarterRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<EnrollStudent>(
          create: (context) => EnrollStudent(
            enrollmentRepository: context.read<EnrollmentRepository>(),
            schoolYearRepository: context.read<SchoolYearRepository>(),
            studentRepository: context.read<StudentRepository>(),
            teachingGroupRepository: context.read<TeachingGroupRepository>(),
          ),
        ),
        Provider<CreateStudentInGroup>(
          create: (context) => CreateStudentInGroup(
            teachingGroupRepository: context.read<TeachingGroupRepository>(),
            schoolYearRepository: context.read<SchoolYearRepository>(),
            enrollmentRepository: context.read<EnrollmentRepository>(),
            writer: context.read<StudentEnrollmentWriter>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<ReactivateStudentInGroup>(
          create: (context) => ReactivateStudentInGroup(
            enrollStudent: context.read<EnrollStudent>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<StudentImportPreviewBuilder>(
          create: (context) => StudentImportPreviewBuilder(
            schoolYearRepository: context.read<SchoolYearRepository>(),
            enrollmentRepository: context.read<EnrollmentRepository>(),
            studentRepository: context.read<StudentRepository>(),
          ),
        ),
        Provider<ImportStudents>(
          create: (context) => ImportStudents(
            previewBuilder: context.read<StudentImportPreviewBuilder>(),
            schoolYearRepository: context.read<SchoolYearRepository>(),
            batchWriter: context.read<StudentEnrollmentBatchWriter>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<BuildDailyAttendance>(
          create: (context) => BuildDailyAttendance(
            attendanceRepository: context.read<AttendanceRepository>(),
            enrollmentRepository: context.read<EnrollmentRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<CreateProject>(
          create: (context) => CreateProject(
            repository: context.read<ProjectRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<CreateActivity>(
          create: (context) => CreateActivity(
            activityRepository: context.read<ActivityRepository>(),
            projectRepository: context.read<ProjectRepository>(),
            enrollmentRepository: context.read<EnrollmentRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<SaveActivityEvaluation>(
          create: (context) => SaveActivityEvaluation(
            activityRepository: context.read<ActivityRepository>(),
            evaluationRepository: context.read<EvaluationRepository>(),
          ),
        ),
        Provider<UpdateStudentRecord>(
          create: (context) => UpdateStudentRecord(
            studentRepository: context.read<StudentRepository>(),
            studentRecordRepository: context.read<StudentRecordRepository>(),
          ),
        ),
        Provider<AddStudentRecordEntry>(
          create: (context) => AddStudentRecordEntry(
            studentRepository: context.read<StudentRepository>(),
            studentRecordRepository: context.read<StudentRecordRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
      ],
      child: child,
    );
  }
}
