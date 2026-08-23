import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
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
