import 'dart:io';
import 'dart:typed_data';

import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/attendance/set_student_attendance_status.dart';
import 'package:aularaiz/application/automation/automation_mutation_service.dart';
import 'package:aularaiz/application/automation/automation_service.dart';
import 'package:aularaiz/application/contracts/database_snapshotter.dart';
import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/literacy/delete_literacy_assessment.dart';
import 'package:aularaiz/application/literacy/save_literacy_assessment.dart';
import 'package:aularaiz/application/literacy/update_literacy_assessment.dart';
import 'package:aularaiz/application/project/create_activity.dart';
import 'package:aularaiz/application/project/create_project.dart';
import 'package:aularaiz/application/reports/report_projection_builder.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/application/student/deactivate_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/application/student_import/import_students.dart';
import 'package:aularaiz/application/student_import/student_import_preview_builder.dart';
import 'package:aularaiz/application/student_record/add_student_record_entry.dart';
import 'package:aularaiz/application/student_record/update_student_record.dart';
import 'package:aularaiz/application/teacher/save_teacher_profile.dart';
import 'package:aularaiz/core/id/uuid_id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/data/repositories/drift_activity_repository.dart';
import 'package:aularaiz/data/repositories/drift_attendance_repository.dart';
import 'package:aularaiz/data/repositories/drift_enrollment_repository.dart';
import 'package:aularaiz/data/repositories/drift_evaluation_repository.dart';
import 'package:aularaiz/data/repositories/drift_literacy_assessment_repository.dart';
import 'package:aularaiz/data/repositories/drift_project_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_year_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_enrollment_batch_writer.dart';
import 'package:aularaiz/data/repositories/drift_student_enrollment_writer.dart';
import 'package:aularaiz/data/repositories/drift_student_record_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_repository.dart';
import 'package:aularaiz/data/repositories/drift_teacher_profile_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:drift/native.dart';

final class AutomationDatabaseLocator {
  const AutomationDatabaseLocator._();

  static List<File> candidates({
    required StorageProfile profile,
    String? explicitPath,
  }) {
    final path = explicitPath?.trim();
    if (path != null && path.isNotEmpty) {
      return <File>[File(path).absolute];
    }

    if (!Platform.isWindows) return const <File>[];
    final appData = Platform.environment['APPDATA']?.trim();
    if (appData == null || appData.isEmpty) return const <File>[];

    final fileName = '${profile.databaseName}.sqlite';
    return <File>[
      File(_join(<String>[appData, 'MindTzijib', 'AulaRaíz', fileName])),
      File(_join(<String>[appData, 'MindTzijib', 'AulaRaiz', fileName])),
    ];
  }

  static Future<File?> findExisting({
    required StorageProfile profile,
    String? explicitPath,
  }) async {
    for (final candidate in candidates(
      profile: profile,
      explicitPath: explicitPath,
    )) {
      if (await candidate.exists()) return candidate;
    }
    return null;
  }

  static String _join(List<String> parts) => parts.join(Platform.pathSeparator);
}

final class AutomationRuntime {
  AutomationRuntime._({
    required this.database,
    required this.service,
    required this.mutations,
  });

  final AppDatabase database;
  final AutomationService service;
  final AutomationMutationService mutations;

  static Future<AutomationRuntime> open({
    required File databaseFile,
    required StorageProfile profile,
  }) async {
    if (!await databaseFile.exists()) {
      throw FileSystemException(
        'AulaRaíz database file does not exist.',
        databaseFile.path,
      );
    }

    final database = AppDatabase.forTesting(
      NativeDatabase(databaseFile),
      storageProfile: profile,
    );

    final idGenerator = UuidIdGenerator();
    final schoolSetupRepository = DriftSchoolSetupRepository(database);
    final schoolYearRepository = DriftSchoolYearRepository(database);
    final teachingGroupRepository = DriftTeachingGroupRepository(database);
    final studentRepository = DriftStudentRepository(database);
    final enrollmentRepository = DriftEnrollmentRepository(database);
    final attendanceRepository = DriftAttendanceRepository(database);
    final projectRepository = DriftProjectRepository(database);
    final activityRepository = DriftActivityRepository(database);
    final evaluationRepository = DriftEvaluationRepository(database);
    final studentRecordRepository = DriftStudentRecordRepository(database);
    final teacherProfileRepository = DriftTeacherProfileRepository(database);
    final literacyAssessmentRepository = DriftLiteracyAssessmentRepository(
      database,
    );
    final saveTeacherProfile = SaveTeacherProfile(
      repository: teacherProfileRepository,
    );
    final updateStudentRecord = UpdateStudentRecord(
      studentRepository: studentRepository,
      studentRecordRepository: studentRecordRepository,
    );

    final reportProjectionBuilder = ReportProjectionBuilder(
      schoolSetupRepository: schoolSetupRepository,
      enrollmentRepository: enrollmentRepository,
      studentRepository: studentRepository,
      attendanceRepository: attendanceRepository,
      projectRepository: projectRepository,
      activityRepository: activityRepository,
      evaluationRepository: evaluationRepository,
      studentRecordRepository: studentRecordRepository,
      teacherProfileRepository: teacherProfileRepository,
    );
    final addStudentRecordEntry = AddStudentRecordEntry(
      studentRepository: studentRepository,
      studentRecordRepository: studentRecordRepository,
      idGenerator: idGenerator,
    );
    final buildDailyAttendance = BuildDailyAttendance(
      attendanceRepository: attendanceRepository,
      enrollmentRepository: enrollmentRepository,
      idGenerator: idGenerator,
    );
    final setStudentAttendanceStatus = SetStudentAttendanceStatus(
      buildDailyAttendance: buildDailyAttendance,
      attendanceRepository: attendanceRepository,
    );
    final saveActivityEvaluation = SaveActivityEvaluation(
      activityRepository: activityRepository,
      evaluationRepository: evaluationRepository,
    );
    final saveLiteracyAssessment = SaveLiteracyAssessment(
      studentRepository: studentRepository,
      repository: literacyAssessmentRepository,
      idGenerator: idGenerator,
    );
    final updateLiteracyAssessment = UpdateLiteracyAssessment(
      repository: literacyAssessmentRepository,
    );
    final deleteLiteracyAssessment = DeleteLiteracyAssessment(
      repository: literacyAssessmentRepository,
    );
    final enrollStudent = EnrollStudent(
      enrollmentRepository: enrollmentRepository,
      schoolYearRepository: schoolYearRepository,
      studentRepository: studentRepository,
      teachingGroupRepository: teachingGroupRepository,
    );
    final deactivateStudentInGroup = DeactivateStudentInGroup(
      enrollmentRepository: enrollmentRepository,
    );
    final reactivateStudentInGroup = ReactivateStudentInGroup(
      enrollStudent: enrollStudent,
      idGenerator: idGenerator,
    );
    final createTeachingGroup = CreateTeachingGroup(
      repository: teachingGroupRepository,
      idGenerator: idGenerator,
    );
    final createInitialWorkspace = CreateInitialWorkspace(
      createSchoolSetup: CreateInitialSchoolSetup(
        repository: schoolSetupRepository,
        idGenerator: idGenerator,
      ),
      createTeachingGroup: createTeachingGroup,
      schoolSetupRepository: schoolSetupRepository,
    );
    final createStudentInGroup = CreateStudentInGroup(
      teachingGroupRepository: teachingGroupRepository,
      schoolYearRepository: schoolYearRepository,
      enrollmentRepository: enrollmentRepository,
      writer: DriftStudentEnrollmentWriter(database),
      idGenerator: idGenerator,
    );
    final createProject = CreateProject(
      repository: projectRepository,
      idGenerator: idGenerator,
    );
    final createActivity = CreateActivity(
      activityRepository: activityRepository,
      projectRepository: projectRepository,
      enrollmentRepository: enrollmentRepository,
      idGenerator: idGenerator,
    );
    final studentImportPreviewBuilder = StudentImportPreviewBuilder(
      schoolYearRepository: schoolYearRepository,
      enrollmentRepository: enrollmentRepository,
      studentRepository: studentRepository,
    );
    final importStudents = ImportStudents(
      previewBuilder: studentImportPreviewBuilder,
      schoolYearRepository: schoolYearRepository,
      batchWriter: DriftStudentEnrollmentBatchWriter(database),
      idGenerator: idGenerator,
    );
    final backupSnapshotter = _AutomationDatabaseSnapshotter(database);

    return AutomationRuntime._(
      database: database,
      service: AutomationService(
        schoolSetupRepository: schoolSetupRepository,
        teachingGroupRepository: teachingGroupRepository,
        studentRepository: studentRepository,
        projectRepository: projectRepository,
        activityRepository: activityRepository,
        enrollmentRepository: enrollmentRepository,
        teacherProfileRepository: teacherProfileRepository,
        groupReportLoader: ({required group, required referenceMonth}) {
          return reportProjectionBuilder.buildGroup(
            group: group,
            referenceMonth: referenceMonth,
          );
        },
        studentNoteWriter:
            ({
              required studentId,
              required kind,
              required occurredAt,
              required text,
            }) async {
              await addStudentRecordEntry(
                studentId: studentId,
                kind: kind,
                occurredAt: occurredAt,
                text: text,
              );
            },
      ),
      mutations: AutomationMutationService(
        teachingGroupRepository: teachingGroupRepository,
        studentRepository: studentRepository,
        enrollmentRepository: enrollmentRepository,
        attendanceRepository: attendanceRepository,
        setStudentAttendanceStatus: setStudentAttendanceStatus,
        saveActivityEvaluation: saveActivityEvaluation,
        deactivateStudentInGroup: deactivateStudentInGroup,
        reactivateStudentInGroup: reactivateStudentInGroup,
        schoolSetupRepository: schoolSetupRepository,
        createInitialWorkspace: createInitialWorkspace,
        createTeachingGroup: createTeachingGroup,
        createStudentInGroup: createStudentInGroup,
        createProject: createProject,
        createActivity: createActivity,
        projectRepository: projectRepository,
        activityRepository: activityRepository,
        saveTeacherProfile: saveTeacherProfile,
        saveLiteracyAssessment: saveLiteracyAssessment,
        updateLiteracyAssessment: updateLiteracyAssessment,
        deleteLiteracyAssessment: deleteLiteracyAssessment,
        updateStudentRecord: updateStudentRecord,
        importStudents: importStudents,
        studentImportPreviewBuilder: studentImportPreviewBuilder,
        backupSnapshotter: backupSnapshotter,
        backupSchemaVersion: AppDatabase.currentSchemaVersion,
        backupStorageProfile: profile.name,
      ),
    );
  }

  Future<void> close() => database.close();
}

final class _AutomationDatabaseSnapshotter implements DatabaseSnapshotter {
  _AutomationDatabaseSnapshotter(this._database);

  final AppDatabase _database;

  static int _sequence = 0;

  @override
  Future<Uint8List> createSnapshot() async {
    final directory = Directory.systemTemp;
    final sequence = _sequence++;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final snapshot = File(
      '${directory.path}${Platform.pathSeparator}'
      'aularaiz-cli-snapshot-$pid-$timestamp-$sequence.sqlite',
    );

    await _deleteIfPresent(snapshot);
    try {
      await _database.customStatement('VACUUM INTO ?', <Object?>[
        snapshot.path,
      ]);
      final bytes = await snapshot.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('SQLite created an empty backup snapshot.');
      }
      return bytes;
    } finally {
      await _deleteIfPresent(snapshot);
      await _deleteIfPresent(File('${snapshot.path}-wal'));
      await _deleteIfPresent(File('${snapshot.path}-shm'));
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }
}
