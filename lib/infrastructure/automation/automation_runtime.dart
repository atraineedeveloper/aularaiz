import 'dart:io';

import 'package:aularaiz/application/automation/automation_service.dart';
import 'package:aularaiz/application/reports/report_projection_builder.dart';
import 'package:aularaiz/application/student_record/add_student_record_entry.dart';
import 'package:aularaiz/core/id/uuid_id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/data/repositories/drift_activity_repository.dart';
import 'package:aularaiz/data/repositories/drift_attendance_repository.dart';
import 'package:aularaiz/data/repositories/drift_enrollment_repository.dart';
import 'package:aularaiz/data/repositories/drift_evaluation_repository.dart';
import 'package:aularaiz/data/repositories/drift_project_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_record_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_repository.dart';
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
  AutomationRuntime._({required this.database, required this.service});

  final AppDatabase database;
  final AutomationService service;

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

    final schoolSetupRepository = DriftSchoolSetupRepository(database);
    final teachingGroupRepository = DriftTeachingGroupRepository(database);
    final studentRepository = DriftStudentRepository(database);
    final enrollmentRepository = DriftEnrollmentRepository(database);
    final attendanceRepository = DriftAttendanceRepository(database);
    final projectRepository = DriftProjectRepository(database);
    final activityRepository = DriftActivityRepository(database);
    final evaluationRepository = DriftEvaluationRepository(database);
    final studentRecordRepository = DriftStudentRecordRepository(database);

    final reportProjectionBuilder = ReportProjectionBuilder(
      schoolSetupRepository: schoolSetupRepository,
      enrollmentRepository: enrollmentRepository,
      studentRepository: studentRepository,
      attendanceRepository: attendanceRepository,
      projectRepository: projectRepository,
      activityRepository: activityRepository,
      evaluationRepository: evaluationRepository,
      studentRecordRepository: studentRecordRepository,
    );
    final addStudentRecordEntry = AddStudentRecordEntry(
      studentRepository: studentRepository,
      studentRecordRepository: studentRecordRepository,
      idGenerator: UuidIdGenerator(),
    );

    return AutomationRuntime._(
      database: database,
      service: AutomationService(
        schoolSetupRepository: schoolSetupRepository,
        teachingGroupRepository: teachingGroupRepository,
        studentRepository: studentRepository,
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
    );
  }

  Future<void> close() => database.close();
}
