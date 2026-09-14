import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';

enum RestoreProblem {
  profileMismatch,
  newerSchema,
  invalidDatabase,
  invalidRequest,
  missingRestoreArtifact,
  stagedArtifactChanged,
  applyFailed,
  rollbackFailed,
}

final class RestoreException implements Exception {
  const RestoreException(this.problem, this.message, [this.cause]);

  final RestoreProblem problem;
  final String message;
  final Object? cause;

  @override
  String toString() => 'RestoreException($problem): $message';
}

final class BackupContentSummary {
  const BackupContentSummary({
    required this.schools,
    required this.schoolYears,
    required this.groups,
    required this.students,
    required this.attendanceDays,
    required this.projects,
    required this.activities,
    required this.evaluations,
    required this.literacyAssessments,
    this.schoolNames = const <String>[],
    this.localModifiedAtUtc,
  });

  final int schools;
  final int schoolYears;
  final int groups;
  final int students;
  final int attendanceDays;
  final int projects;
  final int activities;
  final int evaluations;
  final int literacyAssessments;
  final List<String> schoolNames;
  final DateTime? localModifiedAtUtc;

  int get pedagogicalItems =>
      students +
      attendanceDays +
      projects +
      activities +
      evaluations +
      literacyAssessments;

  bool get hasClassroomData =>
      schools > 0 || groups > 0 || students > 0 || pedagogicalItems > 0;

  BackupContentSummary copyWith({DateTime? localModifiedAtUtc}) {
    return BackupContentSummary(
      schools: schools,
      schoolYears: schoolYears,
      groups: groups,
      students: students,
      attendanceDays: attendanceDays,
      projects: projects,
      activities: activities,
      evaluations: evaluations,
      literacyAssessments: literacyAssessments,
      schoolNames: schoolNames,
      localModifiedAtUtc: localModifiedAtUtc ?? this.localModifiedAtUtc,
    );
  }
}

final class RestorePreview {
  const RestorePreview({required this.manifest, this.summary});

  final BackupManifest manifest;
  final BackupContentSummary? summary;
}

final class StagedRestore {
  const StagedRestore({required this.requestId, required this.preview});

  final String requestId;
  final RestorePreview preview;
}

enum RestoreBootstrapOutcome { none, applied, rolledBack, discarded }
