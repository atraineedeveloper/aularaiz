import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/reports/group_export_models.dart';
import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';

final class ReportProjectionBuilder {
  ReportProjectionBuilder({
    required SchoolSetupRepository schoolSetupRepository,
    required EnrollmentRepository enrollmentRepository,
    required StudentRepository studentRepository,
    required AttendanceRepository attendanceRepository,
    required ProjectRepository projectRepository,
    required ActivityRepository activityRepository,
    required EvaluationRepository evaluationRepository,
    required StudentRecordRepository studentRecordRepository,
  }) : _schoolSetupRepository = schoolSetupRepository,
       _enrollmentRepository = enrollmentRepository,
       _studentRepository = studentRepository,
       _attendanceRepository = attendanceRepository,
       _projectRepository = projectRepository,
       _activityRepository = activityRepository,
       _evaluationRepository = evaluationRepository,
       _studentRecordRepository = studentRecordRepository;

  final SchoolSetupRepository _schoolSetupRepository;
  final EnrollmentRepository _enrollmentRepository;
  final StudentRepository _studentRepository;
  final AttendanceRepository _attendanceRepository;
  final ProjectRepository _projectRepository;
  final ActivityRepository _activityRepository;
  final EvaluationRepository _evaluationRepository;
  final StudentRecordRepository _studentRecordRepository;

  Future<GroupReportData> buildGroup({
    required TeachingGroup group,
    required DateTime referenceMonth,
    ReportPrivacyOptions privacy = const ReportPrivacyOptions(),
  }) async {
    final context = await _loadContext(group, referenceMonth);
    final rows = <StudentReportRow>[];

    for (final enrollment in context.enrollments) {
      final student = await _studentRepository.findById(enrollment.studentId);
      if (student == null) continue;
      rows.add(
        await _buildStudentRow(
          student: student,
          enrollment: enrollment,
          attendance: context.attendance,
          activities: context.activities,
          privacy: privacy,
        ),
      );
    }

    rows.sort((left, right) {
      final byNumber = left.listNumber.compareTo(right.listNumber);
      return byNumber != 0
          ? byNumber
          : left.displayName.compareTo(right.displayName);
    });

    return GroupReportData(
      header: context.header,
      students: List<StudentReportRow>.unmodifiable(rows),
    );
  }

  Future<GroupExportData> buildGroupExport({
    required TeachingGroup group,
    required DateTime referenceMonth,
    ReportPrivacyOptions privacy = const ReportPrivacyOptions(),
  }) async {
    final setup = await _schoolSetupRepository.loadForSchool(group.schoolId);
    if (setup == null) {
      throw StateError('School setup does not exist.');
    }
    if (setup.school.id != group.schoolId ||
        setup.schoolYear.id != group.schoolYearId) {
      throw StateError('Group does not belong to the selected school setup.');
    }

    final month = DateTime(referenceMonth.year, referenceMonth.month);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final enrollments = await _enrollmentRepository.findByGroupId(group.id);
    final studentsById = <String, Student>{};

    Future<Student?> studentFor(String studentId) async {
      final cached = studentsById[studentId];
      if (cached != null) return cached;
      final student = await _studentRepository.findById(studentId);
      if (student != null) studentsById[studentId] = student;
      return student;
    }

    final latestByStudent = <String, Enrollment>{};
    for (final enrollment in enrollments) {
      if (enrollment.startsOn.isAfter(monthEnd)) continue;
      final current = latestByStudent[enrollment.studentId];
      if (current == null || enrollment.startsOn.isAfter(current.startsOn)) {
        latestByStudent[enrollment.studentId] = enrollment;
      }
    }

    final studentRows = <GroupExportStudentRow>[];
    for (final enrollment in latestByStudent.values) {
      final student = await studentFor(enrollment.studentId);
      if (student == null) continue;
      final record = privacy.includeSensitiveFollowUp
          ? await _studentRecordRepository.find(student.id)
          : null;
      studentRows.add(
        GroupExportStudentRow(
          studentId: student.id,
          displayName: student.displayName,
          givenNames: student.givenNames,
          firstSurname: student.firstSurname,
          secondSurname: student.secondSurname,
          sex: student.sex?.name,
          birthDate: student.birthDate,
          age: student.ageOn(monthEnd),
          listNumber: enrollment.listNumber,
          grade: enrollment.grade.number,
          enrollmentStartsOn: enrollment.startsOn,
          enrollmentEndsOn: enrollment.endsOn,
          isActive: enrollment.isActiveOn(monthEnd),
          strengths: record?.strengths,
          difficulties: record?.difficulties,
          supports: record?.supports,
        ),
      );
    }
    studentRows.sort((left, right) {
      final byNumber = left.listNumber.compareTo(right.listNumber);
      return byNumber != 0
          ? byNumber
          : left.displayName.compareTo(right.displayName);
    });

    final attendanceRows = <GroupExportAttendanceRow>[];
    final attendance = [
      ...await _attendanceRepository.listForMonth(group.id, month),
    ];
    attendance.sort((left, right) => left.date.compareTo(right.date));
    for (final day in attendance) {
      for (final entry in day.entries.values) {
        final student = await studentFor(entry.studentId);
        final enrollment = _enrollmentOn(
          enrollments,
          entry.studentId,
          day.date,
        );
        if (student == null || enrollment == null) continue;
        attendanceRows.add(
          GroupExportAttendanceRow(
            date: day.date,
            studentId: student.id,
            listNumber: enrollment.listNumber,
            studentName: student.displayName,
            grade: enrollment.grade.number,
            status: entry.status.name,
          ),
        );
      }
    }
    attendanceRows.sort((left, right) {
      final byDate = left.date.compareTo(right.date);
      if (byDate != 0) return byDate;
      final byNumber = left.listNumber.compareTo(right.listNumber);
      return byNumber != 0
          ? byNumber
          : left.studentName.compareTo(right.studentName);
    });

    final projects = [...await _projectRepository.listForGroup(group.id)];
    projects.sort((left, right) => left.title.compareTo(right.title));
    final projectRows = <GroupExportProjectRow>[];
    final activityRows = <GroupExportActivityRow>[];
    final activities = <Activity>[];
    final projectById = <String, Project>{};
    for (final project in projects) {
      projectById[project.id] = project;
      final grades = project.targetGrades.map((grade) => grade.number).toList()
        ..sort();
      final axes = project.articulatingAxes.map((axis) => axis.name).toList()
        ..sort();
      projectRows.add(
        GroupExportProjectRow(
          projectId: project.id,
          title: project.title,
          description: project.description,
          startsOn: project.startsOn,
          endsOn: project.endsOn,
          observations: project.observations,
          lifecycle: project.lifecycle.name,
          methodology: project.methodology.name,
          targetGrades: List<int>.unmodifiable(grades),
          articulatingAxes: List<String>.unmodifiable(axes),
        ),
      );

      final projectActivities = [
        ...await _activityRepository.listForProject(project.id),
      ];
      projectActivities.sort((left, right) {
        final leftDate = left.occursOn;
        final rightDate = right.occursOn;
        if (leftDate != null && rightDate != null) {
          final byDate = leftDate.compareTo(rightDate);
          if (byDate != 0) return byDate;
        } else if (leftDate != null) {
          return -1;
        } else if (rightDate != null) {
          return 1;
        }
        return left.title.compareTo(right.title);
      });
      activities.addAll(projectActivities);
      for (final activity in projectActivities) {
        final grades =
            activity.targetGrades.map((grade) => grade.number).toList()..sort();
        activityRows.add(
          GroupExportActivityRow(
            projectId: project.id,
            projectTitle: project.title,
            activityId: activity.id,
            identifier: activity.displayIdentifier,
            title: activity.title,
            description: activity.description,
            occursOn: activity.occursOn,
            generalObservations: activity.generalObservations,
            formativeField: activity.formativeField.name,
            targetGrades: List<int>.unmodifiable(grades),
            participantCount: activity.roster.length,
          ),
        );
      }
    }

    final evaluationRows = <GroupExportEvaluationRow>[];
    for (final activity in activities) {
      final project = projectById[activity.projectId];
      if (project == null) continue;
      final saved = await _evaluationRepository.listForActivity(activity.id);
      final savedByStudent = <String, ActivityEvaluation>{
        for (final evaluation in saved) evaluation.studentId: evaluation,
      };
      for (final participant in activity.roster.values) {
        final student = await studentFor(participant.studentId);
        if (student == null) continue;
        final referenceDate = activity.occursOn ?? monthEnd;
        final enrollment =
            _enrollmentOn(enrollments, student.id, referenceDate) ??
            _latestEnrollmentOnOrBefore(enrollments, student.id, referenceDate);
        final evaluation = savedByStudent[student.id];
        evaluationRows.add(
          GroupExportEvaluationRow(
            projectId: project.id,
            projectTitle: project.title,
            activityId: activity.id,
            activityIdentifier: activity.displayIdentifier,
            activityTitle: activity.title,
            activityDate: activity.occursOn,
            studentId: student.id,
            listNumber: enrollment?.listNumber,
            studentName: student.displayName,
            grade: participant.grade.number,
            resultState: evaluation?.state.name ?? 'pendingDeliveryDecision',
            deliveryStatus:
                evaluation?.deliveryStatus.name ?? DeliveryStatus.pending.name,
            achievement: evaluation?.achievement?.name,
            observation: privacy.includeSensitiveFollowUp
                ? evaluation?.observation
                : null,
          ),
        );
      }
    }
    evaluationRows.sort((left, right) {
      final byProject = left.projectTitle.compareTo(right.projectTitle);
      if (byProject != 0) return byProject;
      final byActivity = left.activityTitle.compareTo(right.activityTitle);
      if (byActivity != 0) return byActivity;
      final leftNumber = left.listNumber ?? 1 << 30;
      final rightNumber = right.listNumber ?? 1 << 30;
      final byNumber = leftNumber.compareTo(rightNumber);
      return byNumber != 0
          ? byNumber
          : left.studentName.compareTo(right.studentName);
    });

    final followUpRows = <GroupExportFollowUpRow>[];
    if (privacy.includeSensitiveFollowUp) {
      for (final row in studentRows) {
        final entries = await _studentRecordRepository.listEntries(
          row.studentId,
        );
        for (final entry in entries) {
          final occurredOn = _dateOnly(entry.occurredAt.toLocal());
          final enrollment =
              _enrollmentOn(enrollments, row.studentId, occurredOn) ??
              _latestEnrollmentOnOrBefore(
                enrollments,
                row.studentId,
                occurredOn,
              );
          followUpRows.add(
            GroupExportFollowUpRow(
              studentId: row.studentId,
              listNumber: enrollment?.listNumber,
              studentName: row.displayName,
              grade: enrollment?.grade.number,
              kind: entry.kind.name,
              occurredAt: entry.occurredAt,
              text: entry.text,
            ),
          );
        }
      }
      followUpRows.sort((left, right) {
        final byDate = left.occurredAt.compareTo(right.occurredAt);
        return byDate != 0
            ? byDate
            : left.studentName.compareTo(right.studentName);
      });
    }

    final grades = group.grades.map((grade) => grade.number).toList()..sort();
    final phases = group.phases.map((phase) => phase.name).toList()..sort();
    return GroupExportData(
      context: GroupExportContextData(
        schoolName: setup.school.name,
        cct: setup.school.cct,
        state: setup.school.state,
        municipality: setup.school.municipality,
        locality: setup.school.locality,
        schoolOrganization: setup.school.organization.name,
        schoolYearLabel: setup.schoolYear.label,
        groupName: group.name,
        shift: group.shift,
        grades: List<int>.unmodifiable(grades),
        isMultigrade: group.isMultigrade,
        phases: List<String>.unmodifiable(phases),
        startsAtMinutes: group.schedule?.startsAtMinutes,
        endsAtMinutes: group.schedule?.endsAtMinutes,
        referenceMonth: month,
      ),
      students: List<GroupExportStudentRow>.unmodifiable(studentRows),
      attendance: List<GroupExportAttendanceRow>.unmodifiable(attendanceRows),
      projects: List<GroupExportProjectRow>.unmodifiable(projectRows),
      activities: List<GroupExportActivityRow>.unmodifiable(activityRows),
      evaluations: List<GroupExportEvaluationRow>.unmodifiable(evaluationRows),
      followUp: List<GroupExportFollowUpRow>.unmodifiable(followUpRows),
      includeSensitiveFollowUp: privacy.includeSensitiveFollowUp,
    );
  }

  Future<IndividualReportData> buildIndividual({
    required TeachingGroup group,
    required String studentId,
    required DateTime referenceMonth,
    ReportPrivacyOptions privacy = const ReportPrivacyOptions(),
  }) async {
    final context = await _loadContext(group, referenceMonth);
    final enrollment = context.enrollments
        .where((value) => value.studentId == studentId)
        .firstOrNull;
    if (enrollment == null) {
      throw StateError('Student is not part of this group during the month.');
    }

    final student = await _studentRepository.findById(studentId);
    if (student == null) {
      throw StateError('Student does not exist.');
    }

    final row = await _buildStudentRow(
      student: student,
      enrollment: enrollment,
      attendance: context.attendance,
      activities: context.activities,
      privacy: privacy,
    );
    final evaluations = await _evaluationItems(
      studentId: studentId,
      activities: context.activities,
      includeObservation: privacy.includeSensitiveFollowUp,
    );

    final followUp = <ReportFollowUpItem>[];
    if (privacy.includeSensitiveFollowUp) {
      final entries = await _studentRecordRepository.listEntries(studentId);
      followUp.addAll(
        entries.map(
          (entry) => ReportFollowUpItem(
            kind: entry.kind,
            occurredAt: entry.occurredAt,
            text: entry.text,
          ),
        ),
      );
    }

    return IndividualReportData(
      header: context.header,
      student: row,
      evaluations: evaluations,
      followUp: List<ReportFollowUpItem>.unmodifiable(followUp),
    );
  }

  Future<_ReportContext> _loadContext(
    TeachingGroup group,
    DateTime referenceMonth,
  ) async {
    final setup = await _schoolSetupRepository.loadForSchool(group.schoolId);
    if (setup == null) {
      throw StateError('School setup does not exist.');
    }
    if (setup.school.id != group.schoolId ||
        setup.schoolYear.id != group.schoolYearId) {
      throw StateError('Group does not belong to the selected school setup.');
    }

    final month = DateTime(referenceMonth.year, referenceMonth.month);
    final monthStart = month;
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final enrollments = await _enrollmentRepository.findByGroupId(group.id);
    final latestByStudent = <String, Enrollment>{};
    for (final enrollment in enrollments) {
      if (!_overlaps(enrollment, monthStart, monthEnd)) continue;
      final current = latestByStudent[enrollment.studentId];
      if (current == null || enrollment.startsOn.isAfter(current.startsOn)) {
        latestByStudent[enrollment.studentId] = enrollment;
      }
    }

    final attendance = await _attendanceRepository.listForMonth(
      group.id,
      month,
    );
    final projects = await _projectRepository.listForGroup(group.id);
    final activities = <Activity>[];
    for (final project in projects) {
      activities.addAll(await _activityRepository.listForProject(project.id));
    }

    return _ReportContext(
      header: ReportHeader(
        schoolName: setup.school.name,
        cct: setup.school.cct,
        state: setup.school.state,
        municipality: setup.school.municipality,
        locality: setup.school.locality,
        schoolYearLabel: setup.schoolYear.label,
        groupName: group.name,
        referenceMonth: month,
      ),
      enrollments: List<Enrollment>.unmodifiable(latestByStudent.values),
      attendance: List<DailyAttendance>.unmodifiable(attendance),
      activities: List<Activity>.unmodifiable(activities),
    );
  }

  Future<StudentReportRow> _buildStudentRow({
    required Student student,
    required Enrollment enrollment,
    required List<DailyAttendance> attendance,
    required List<Activity> activities,
    required ReportPrivacyOptions privacy,
  }) async {
    var present = 0;
    var absent = 0;
    var late = 0;
    var justified = 0;
    for (final day in attendance) {
      final status = day.statusFor(student.id);
      switch (status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.justifiedAbsence:
          justified++;
        case null:
          break;
      }
    }

    final evaluations = await _evaluationItems(
      studentId: student.id,
      activities: activities,
      includeObservation: false,
    );
    final evaluationSummary = _summarizeEvaluations(evaluations);

    String? strengths;
    String? difficulties;
    String? supports;
    if (privacy.includeSensitiveFollowUp) {
      final record = await _studentRecordRepository.find(student.id);
      strengths = record?.strengths;
      difficulties = record?.difficulties;
      supports = record?.supports;
    }

    return StudentReportRow(
      studentId: student.id,
      displayName: student.displayName,
      listNumber: enrollment.listNumber,
      grade: enrollment.grade,
      sex: student.sex,
      attendance: AttendanceReportSummary(
        present: present,
        absent: absent,
        late: late,
        justifiedAbsence: justified,
      ),
      evaluation: evaluationSummary,
      strengths: strengths,
      difficulties: difficulties,
      supports: supports,
    );
  }

  Future<List<EvaluationReportItem>> _evaluationItems({
    required String studentId,
    required List<Activity> activities,
    required bool includeObservation,
  }) async {
    final saved = await _evaluationRepository.listForStudent(studentId);
    final savedByActivity = <String, ActivityEvaluation>{
      for (final evaluation in saved) evaluation.activityId: evaluation,
    };
    final items = <EvaluationReportItem>[];

    for (final activity in activities) {
      if (!activity.roster.containsKey(studentId)) continue;
      final evaluation = savedByActivity[activity.id];
      items.add(
        EvaluationReportItem(
          activityId: activity.id,
          activityTitle: activity.title,
          deliveryStatus: evaluation?.deliveryStatus ?? DeliveryStatus.pending,
          achievement: evaluation?.achievement,
          observation: includeObservation ? evaluation?.observation : null,
        ),
      );
    }

    items.sort(
      (left, right) => left.activityTitle.compareTo(right.activityTitle),
    );
    return List<EvaluationReportItem>.unmodifiable(items);
  }

  EvaluationReportSummary _summarizeEvaluations(
    List<EvaluationReportItem> evaluations,
  ) {
    var pending = 0;
    var delivered = 0;
    var notDelivered = 0;
    var evaluated = 0;
    var mastered = 0;
    var sufficient = 0;
    var inProgress = 0;
    var requiresSupport = 0;

    for (final evaluation in evaluations) {
      switch (evaluation.deliveryStatus) {
        case DeliveryStatus.pending:
          pending++;
        case DeliveryStatus.delivered:
          delivered++;
        case DeliveryStatus.notDelivered:
          notDelivered++;
      }
      switch (evaluation.achievement) {
        case AchievementLevel.mastered:
          evaluated++;
          mastered++;
        case AchievementLevel.sufficient:
          evaluated++;
          sufficient++;
        case AchievementLevel.inProgress:
          evaluated++;
          inProgress++;
        case AchievementLevel.requiresSupport:
          evaluated++;
          requiresSupport++;
        case null:
          break;
      }
    }

    return EvaluationReportSummary(
      pending: pending,
      delivered: delivered,
      notDelivered: notDelivered,
      evaluated: evaluated,
      mastered: mastered,
      sufficient: sufficient,
      inProgress: inProgress,
      requiresSupport: requiresSupport,
    );
  }

  Enrollment? _enrollmentOn(
    List<Enrollment> enrollments,
    String studentId,
    DateTime date,
  ) {
    Enrollment? selected;
    for (final enrollment in enrollments) {
      if (enrollment.studentId != studentId || !enrollment.isActiveOn(date)) {
        continue;
      }
      if (selected == null || enrollment.startsOn.isAfter(selected.startsOn)) {
        selected = enrollment;
      }
    }
    return selected;
  }

  Enrollment? _latestEnrollmentOnOrBefore(
    List<Enrollment> enrollments,
    String studentId,
    DateTime date,
  ) {
    Enrollment? selected;
    for (final enrollment in enrollments) {
      if (enrollment.studentId != studentId ||
          enrollment.startsOn.isAfter(date)) {
        continue;
      }
      if (selected == null || enrollment.startsOn.isAfter(selected.startsOn)) {
        selected = enrollment;
      }
    }
    return selected;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _overlaps(Enrollment enrollment, DateTime start, DateTime end) {
    if (enrollment.startsOn.isAfter(end)) return false;
    final enrollmentEnd = enrollment.endsOn;
    return enrollmentEnd == null || !enrollmentEnd.isBefore(start);
  }
}

final class _ReportContext {
  const _ReportContext({
    required this.header,
    required this.enrollments,
    required this.attendance,
    required this.activities,
  });

  final ReportHeader header;
  final List<Enrollment> enrollments;
  final List<DailyAttendance> attendance;
  final List<Activity> activities;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
