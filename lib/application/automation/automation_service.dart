import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teacher_profile_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';

typedef AutomationClock = DateTime Function();

typedef AutomationGroupReportLoader = Future<GroupReportData> Function({
  required TeachingGroup group,
  required DateTime referenceMonth,
});

typedef AutomationStudentNoteWriter = Future<void> Function({
  required String studentId,
  required StudentRecordEntryKind kind,
  required DateTime occurredAt,
  required String text,
});

final class AutomationService {
  AutomationService({
    required SchoolSetupRepository schoolSetupRepository,
    required TeachingGroupRepository teachingGroupRepository,
    required StudentRepository studentRepository,
    required ProjectRepository projectRepository,
    required ActivityRepository activityRepository,
    required EnrollmentRepository enrollmentRepository,
    required AutomationGroupReportLoader groupReportLoader,
    required AutomationStudentNoteWriter studentNoteWriter,
    TeacherProfileRepository? teacherProfileRepository,
    AutomationClock? clock,
  }) : _schoolSetupRepository = schoolSetupRepository,
       _teachingGroupRepository = teachingGroupRepository,
       _studentRepository = studentRepository,
       _projectRepository = projectRepository,
       _activityRepository = activityRepository,
       _enrollmentRepository = enrollmentRepository,
       _groupReportLoader = groupReportLoader,
       _studentNoteWriter = studentNoteWriter,
       _teacherProfileRepository = teacherProfileRepository,
       _clock = clock ?? DateTime.now;

  final SchoolSetupRepository _schoolSetupRepository;
  final TeachingGroupRepository _teachingGroupRepository;
  final StudentRepository _studentRepository;
  final ProjectRepository _projectRepository;
  final ActivityRepository _activityRepository;
  final EnrollmentRepository _enrollmentRepository;
  final AutomationGroupReportLoader _groupReportLoader;
  final AutomationStudentNoteWriter _studentNoteWriter;
  final TeacherProfileRepository? _teacherProfileRepository;
  final AutomationClock _clock;

  Future<AutomationEnvelope> status({
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final setup = await _schoolSetupRepository.loadInitialSetup();
    var groupCount = 0;
    if (setup != null) {
      groupCount = (await _teachingGroupRepository.listForSchoolYear(
        setup.schoolYear.id,
      )).length;
    }

    // Teacher profile data is never part of the default (minimized) output;
    // it is only echoed with an explicit --include-personal-data request.
    String? teacherName;
    if (privacy.includePersonalData) {
      final repository = _teacherProfileRepository;
      if (repository != null) {
        try {
          teacherName = (await repository.load())?.fullName;
        } catch (_) {
          teacherName = null;
        }
      }
    }

    return _envelope(
      kind: 'status',
      privacy: privacy,
      data: <String, Object?>{
        'configured': setup != null,
        'schema_version': 1,
        if (setup != null) 'school_year': setup.schoolYear.label,
        'group_count': groupCount,
        'teacher_name': ?teacherName,
        'capabilities': AutomationCapabilityCatalog.capabilities,
      },
    );
  }

  Future<AutomationEnvelope> listSchools({
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final setups = await _schoolSetupRepository.listSetups();
    return _envelope(
      kind: 'schools',
      privacy: privacy,
      data: <String, Object?>{
        'schools': [
          for (final setup in setups)
            <String, Object?>{
              'id': setup.school.id,
              'name': setup.school.name,
              'school_year': setup.schoolYear.label,
              'school_year_id': setup.schoolYear.id,
              'organization': setup.school.organization.name,
              if (setup.school.schoolZone != null)
                'school_zone': setup.school.schoolZone,
              if (setup.school.schoolSector != null)
                'school_sector': setup.school.schoolSector,
              if (privacy.includePersonalData) ...<String, Object?>{
                if (setup.school.supervisorName != null)
                  'supervisor_name': setup.school.supervisorName,
                if (setup.school.leadershipName != null)
                  'leadership_name': setup.school.leadershipName,
                if (setup.school.leadershipRole != null)
                  'leadership_role': setup.school.leadershipRole!.name,
              },
            },
        ],
      },
    );
  }

  Future<AutomationEnvelope> listGroups() async {
    final setup = await _schoolSetupRepository.loadInitialSetup();
    if (setup == null) {
      throw StateError('AulaRaíz has no active school setup.');
    }

    final groups = await _teachingGroupRepository.listForSchoolYear(
      setup.schoolYear.id,
    );
    groups.sort((left, right) => left.name.compareTo(right.name));

    return _envelope(
      kind: 'groups',
      privacy: const AutomationPrivacy(),
      data: <String, Object?>{
        'school_year': setup.schoolYear.label,
        'groups': groups.map(_groupProjection).toList(growable: false),
      },
    );
  }

  Future<AutomationEnvelope> listProjects({required String groupId}) async {
    final group = await _requireGroup(groupId);
    final projects = List<Project>.of(
      await _projectRepository.listForGroup(group.id),
    );
    projects.sort((left, right) => left.title.compareTo(right.title));

    return _envelope(
      kind: 'projects',
      privacy: const AutomationPrivacy(),
      data: <String, Object?>{
        'group': _groupProjection(group),
        'project_count': projects.length,
        'projects': projects.map(_projectProjection).toList(growable: false),
      },
    );
  }

  Future<AutomationEnvelope> listActivities({required String projectId}) async {
    final project = await _projectRepository.findById(projectId);
    if (project == null) throw StateError('Project does not exist.');

    final activities = List<Activity>.of(
      await _activityRepository.listForProject(project.id),
    );
    activities.sort((left, right) {
      final byTitle = left.title.compareTo(right.title);
      if (byTitle != 0) return byTitle;
      final leftDate = left.occursOn;
      final rightDate = right.occursOn;
      if (leftDate == null || rightDate == null) return 0;
      return leftDate.compareTo(rightDate);
    });

    return _envelope(
      kind: 'activities',
      privacy: const AutomationPrivacy(),
      data: <String, Object?>{
        'project': <String, Object?>{'id': project.id, 'title': project.title},
        'activity_count': activities.length,
        'activities': activities
            .map(_activityProjection)
            .toList(growable: false),
      },
    );
  }

  Future<AutomationEnvelope> listStudents({
    required String groupId,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final now = _date(_clock());
    final enrollments = await _enrollmentRepository.findByGroupId(group.id);
    final latestByStudent = <String, Enrollment>{};
    for (final enrollment in enrollments) {
      final current = latestByStudent[enrollment.studentId];
      if (current == null || enrollment.startsOn.isAfter(current.startsOn)) {
        latestByStudent[enrollment.studentId] = enrollment;
      }
    }

    final students = <_AutomationStudentRow>[];
    for (final enrollment in latestByStudent.values) {
      final student = await _studentRepository.findById(enrollment.studentId);
      if (student == null) continue;
      students.add(
        _AutomationStudentRow(
          student: student,
          enrollment: enrollment,
          active: enrollment.isActiveOn(now),
        ),
      );
    }
    students.sort((left, right) => left.listNumber.compareTo(right.listNumber));

    final gradeCounts = <int, int>{};
    for (final row in students) {
      final grade = row.enrollment.grade.number;
      gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;
    }

    return _envelope(
      kind: 'students',
      privacy: privacy,
      data: <String, Object?>{
        'group': _groupProjection(group),
        'student_count': students.length,
        'active_count': students.where((row) => row.active).length,
        'inactive_count': students.where((row) => !row.active).length,
        'enrollment_by_grade': <String, Object?>{
          for (final entry in gradeCounts.entries)
            entry.key.toString(): entry.value,
        },
        if (privacy.includePersonalData)
          'students': students.map(_personalStudentRow).toList(growable: false),
      },
    );
  }

  Future<AutomationEnvelope> groupSummary({
    required String groupId,
    required DateTime referenceMonth,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final month = _month(referenceMonth);
    final report = await _groupReportLoader(
      group: group,
      referenceMonth: month,
    );

    final attendance = _aggregateAttendance(report.students);
    final evaluation = _aggregateEvaluation(report.students);

    return _envelope(
      kind: 'group-summary',
      privacy: privacy,
      data: <String, Object?>{
        'group': _groupProjection(group),
        'month': _monthLabel(month),
        'student_count': report.students.length,
        'attendance': attendance,
        'evaluation': evaluation,
        if (privacy.includePersonalData)
          'students': report.students
              .map(_personalStudentProjection)
              .toList(growable: false),
      },
    );
  }

  Future<GroupReportData> loadGroupReport({
    required String groupId,
    required DateTime referenceMonth,
  }) async {
    final group = await _requireGroup(groupId);
    return _groupReportLoader(
      group: group,
      referenceMonth: _month(referenceMonth),
    );
  }

  Future<AutomationEnvelope> recommendations({
    required String groupId,
    required DateTime referenceMonth,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final month = _month(referenceMonth);
    final report = await _groupReportLoader(
      group: group,
      referenceMonth: month,
    );

    final recommendations = <AutomationRecommendation>[];
    final absenceTargets = report.students
        .where((row) => row.attendance.absent >= 2)
        .toList(growable: false);
    final lateTargets = report.students
        .where((row) => row.attendance.late >= 2)
        .toList(growable: false);
    final supportTargets = report.students
        .where((row) => row.evaluation.requiresSupport > 0)
        .toList(growable: false);
    final nonDeliveryTargets = report.students
        .where((row) => row.evaluation.notDelivered > 0)
        .toList(growable: false);
    final pendingTargets = report.students
        .where((row) => row.evaluation.pending >= 2)
        .toList(growable: false);

    if (absenceTargets.isNotEmpty) {
      recommendations.add(
        _recommendation(
          code: 'review-attendance-absences',
          message: 'Revisar patrones de inasistencia y el contexto antes de definir apoyos.',
          metric: 'students_with_two_or_more_absences',
          threshold: 2,
          targets: absenceTargets,
        ),
      );
    }
    if (lateTargets.isNotEmpty) {
      recommendations.add(
        _recommendation(
          code: 'review-attendance-lateness',
          message: 'Revisar retardos recurrentes y su contexto antes de tomar medidas.',
          metric: 'students_with_two_or_more_lates',
          threshold: 2,
          targets: lateTargets,
        ),
      );
    }
    if (supportTargets.isNotEmpty) {
      recommendations.add(
        _recommendation(
          code: 'review-learning-support',
          message: 'Revisar evidencias de aprendizaje marcadas como requiere apoyo y considerar ajustes pedagógicos.',
          metric: 'students_with_requires_support_evaluations',
          threshold: 1,
          targets: supportTargets,
        ),
      );
    }
    if (nonDeliveryTargets.isNotEmpty) {
      recommendations.add(
        _recommendation(
          code: 'review-non-delivery',
          message: 'Revisar actividades no entregadas distinguiéndolas del nivel de logro.',
          metric: 'students_with_not_delivered_activities',
          threshold: 1,
          targets: nonDeliveryTargets,
        ),
      );
    }
    if (pendingTargets.isNotEmpty) {
      recommendations.add(
        _recommendation(
          code: 'review-pending-evaluations',
          message: 'Revisar evaluaciones pendientes para mantener el seguimiento formativo al día.',
          metric: 'students_with_two_or_more_pending_evaluations',
          threshold: 2,
          targets: pendingTargets,
        ),
      );
    }

    return _envelope(
      kind: 'recommendations',
      privacy: privacy,
      data: <String, Object?>{
        'group': _groupProjection(group),
        'month': _monthLabel(month),
        'student_count': report.students.length,
        'recommendations': recommendations
            .map(
              (value) => value.toJson(
                includePersonalData: privacy.includePersonalData,
              ),
            )
            .toList(growable: false),
        'interpretation': 'Las recomendaciones son señales para revisión docente; no son diagnósticos ni decisiones automáticas.',
      },
    );
  }

  Future<AutomationEnvelope> studentNote({
    required String studentId,
    required StudentRecordEntryKind kind,
    required DateTime occurredAt,
    required String text,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Note text cannot be empty.');
    }

    final student = await _studentRepository.findById(studentId);
    if (student == null) {
      throw StateError('Student does not exist.');
    }

    if (apply) {
      await _studentNoteWriter(
        studentId: student.id,
        kind: kind,
        occurredAt: occurredAt,
        text: normalizedText,
      );
    }

    return _envelope(
      kind: 'student-note',
      privacy: privacy,
      data: <String, Object?>{
        'operation': 'add-student-record-entry',
        'dry_run': !apply,
        'applied': apply,
        'entry_kind': kind.name,
        'occurred_at': _dateLabel(occurredAt),
        'text_length': normalizedText.length,
        'text_echoed': false,
        if (privacy.includePersonalData)
          'student': _personalStudentIdentity(student),
      },
    );
  }

  AutomationRecommendation _recommendation({
    required String code,
    required String message,
    required String metric,
    required int threshold,
    required List<StudentReportRow> targets,
  }) {
    return AutomationRecommendation(
      code: code,
      message: message,
      evidence: <String, Object?>{
        'metric': metric,
        'threshold': threshold,
        'affected_students': targets.length,
      },
      targets: targets.map(_personalTarget).toList(growable: false),
    );
  }

  Future<TeachingGroup> _requireGroup(String groupId) async {
    if (groupId.trim().isEmpty) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Group id cannot be empty.',
      );
    }
    final group = await _teachingGroupRepository.findById(groupId);
    if (group == null) throw StateError('Teaching group does not exist.');
    return group;
  }

  AutomationEnvelope _envelope({
    required String kind,
    required AutomationPrivacy privacy,
    required Map<String, Object?> data,
  }) {
    return AutomationEnvelope(
      kind: kind,
      privacy: privacy,
      data: data,
      generatedAt: _clock(),
    );
  }
}

Map<String, Object?> _groupProjection(TeachingGroup group) => <String, Object?>{
  'id': group.id,
  'name': group.name,
  'grades': group.grades.map((grade) => grade.number).toList(growable: false)
    ..sort(),
  'multigrade': group.isMultigrade,
  if (group.shift != null) 'shift': group.shift,
};

Map<String, Object?> _projectProjection(Project project) => <String, Object?>{
  'id': project.id,
  'title': project.title,
  'lifecycle': project.lifecycle.name,
  'methodology': project.methodology.name,
  'grades':
      project.targetGrades.map((grade) => grade.number).toList(growable: false)
        ..sort(),
};

Map<String, Object?> _activityProjection(
  Activity activity,
) => <String, Object?>{
  'id': activity.id,
  'title': activity.title,
  'formative_field': activity.formativeField.name,
  'grades':
      activity.targetGrades.map((grade) => grade.number).toList(growable: false)
        ..sort(),
  if (activity.occursOn != null) 'occurs_on': _dateLabel(activity.occursOn!),
};

final class _AutomationStudentRow {
  const _AutomationStudentRow({
    required this.student,
    required this.enrollment,
    required this.active,
  });

  final Student student;
  final Enrollment enrollment;
  final bool active;

  int get listNumber => enrollment.listNumber;
}

Map<String, Object?> _personalStudentRow(_AutomationStudentRow row) =>
    <String, Object?>{
      'student_id': row.student.id,
      'name': row.student.displayName,
      'list_number': row.enrollment.listNumber,
      'grade': row.enrollment.grade.number,
      'active': row.active,
      'starts_on': _dateLabel(row.enrollment.startsOn),
      if (row.enrollment.endsOn != null)
        'ends_on': _dateLabel(row.enrollment.endsOn!),
    };

Map<String, Object?> _aggregateAttendance(List<StudentReportRow> rows) {
  var present = 0;
  var absent = 0;
  var late = 0;
  var justifiedAbsence = 0;
  for (final row in rows) {
    present += row.attendance.present;
    absent += row.attendance.absent;
    late += row.attendance.late;
    justifiedAbsence += row.attendance.justifiedAbsence;
  }
  final marked = present + absent + late + justifiedAbsence;
  return <String, Object?>{
    'present': present,
    'absent': absent,
    'late': late,
    'justified_absence': justifiedAbsence,
    'marked': marked,
    'present_rate': marked == 0 ? null : present / marked,
  };
}

Map<String, Object?> _aggregateEvaluation(List<StudentReportRow> rows) {
  var pending = 0;
  var delivered = 0;
  var notDelivered = 0;
  var evaluated = 0;
  var mastered = 0;
  var sufficient = 0;
  var inProgress = 0;
  var requiresSupport = 0;
  for (final row in rows) {
    pending += row.evaluation.pending;
    delivered += row.evaluation.delivered;
    notDelivered += row.evaluation.notDelivered;
    evaluated += row.evaluation.evaluated;
    mastered += row.evaluation.mastered;
    sufficient += row.evaluation.sufficient;
    inProgress += row.evaluation.inProgress;
    requiresSupport += row.evaluation.requiresSupport;
  }
  return <String, Object?>{
    'pending': pending,
    'delivered': delivered,
    'not_delivered': notDelivered,
    'evaluated': evaluated,
    'mastered': mastered,
    'sufficient': sufficient,
    'in_progress': inProgress,
    'requires_support': requiresSupport,
  };
}

Map<String, Object?> _personalStudentProjection(StudentReportRow row) {
  return <String, Object?>{
    ..._personalTarget(row),
    'attendance': <String, Object?>{
      'present': row.attendance.present,
      'absent': row.attendance.absent,
      'late': row.attendance.late,
      'justified_absence': row.attendance.justifiedAbsence,
    },
    'evaluation': <String, Object?>{
      'pending': row.evaluation.pending,
      'delivered': row.evaluation.delivered,
      'not_delivered': row.evaluation.notDelivered,
      'evaluated': row.evaluation.evaluated,
      'mastered': row.evaluation.mastered,
      'sufficient': row.evaluation.sufficient,
      'in_progress': row.evaluation.inProgress,
      'requires_support': row.evaluation.requiresSupport,
    },
  };
}

Map<String, Object?> _personalTarget(StudentReportRow row) => <String, Object?>{
  'student_id': row.studentId,
  'name': row.displayName,
  'list_number': row.listNumber,
  'grade': row.grade.number,
};

Map<String, Object?> _personalStudentIdentity(Student student) =>
    <String, Object?>{'student_id': student.id, 'name': student.displayName};

DateTime _month(DateTime value) => DateTime(value.year, value.month);

DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);

String _monthLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';

String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
