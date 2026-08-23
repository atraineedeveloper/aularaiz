import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/student/student_sex.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';

final class ReportPrivacyOptions {
  const ReportPrivacyOptions({this.includeSensitiveFollowUp = false});

  final bool includeSensitiveFollowUp;
}

final class AttendanceReportSummary {
  const AttendanceReportSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.justifiedAbsence,
  });

  final int present;
  final int absent;
  final int late;
  final int justifiedAbsence;

  int get totalMarked => present + absent + late + justifiedAbsence;
}

final class EvaluationReportSummary {
  const EvaluationReportSummary({
    required this.pending,
    required this.delivered,
    required this.notDelivered,
    required this.evaluated,
    required this.mastered,
    required this.sufficient,
    required this.inProgress,
    required this.requiresSupport,
  });

  final int pending;
  final int delivered;
  final int notDelivered;
  final int evaluated;
  final int mastered;
  final int sufficient;
  final int inProgress;
  final int requiresSupport;

  int get decidedDeliveries => delivered + notDelivered;

  double? get deliveryCompliance =>
      decidedDeliveries == 0 ? null : delivered / decidedDeliveries;
}

final class ReportHeader {
  const ReportHeader({
    required this.schoolName,
    required this.schoolYearLabel,
    required this.groupName,
    required this.referenceMonth,
    this.cct,
    this.state,
    this.municipality,
    this.locality,
  });

  final String schoolName;
  final String schoolYearLabel;
  final String groupName;
  final DateTime referenceMonth;
  final String? cct;
  final String? state;
  final String? municipality;
  final String? locality;
}

final class StudentReportRow {
  const StudentReportRow({
    required this.studentId,
    required this.displayName,
    required this.listNumber,
    required this.grade,
    required this.attendance,
    required this.evaluation,
    this.sex,
    this.strengths,
    this.difficulties,
    this.supports,
  });

  final String studentId;
  final String displayName;
  final int listNumber;
  final PrimaryGrade grade;
  final StudentSex? sex;
  final AttendanceReportSummary attendance;
  final EvaluationReportSummary evaluation;
  final String? strengths;
  final String? difficulties;
  final String? supports;
}

final class EvaluationReportItem {
  const EvaluationReportItem({
    required this.activityId,
    required this.activityTitle,
    required this.deliveryStatus,
    required this.achievement,
    this.observation,
  });

  final String activityId;
  final String activityTitle;
  final DeliveryStatus deliveryStatus;
  final AchievementLevel? achievement;
  final String? observation;
}

final class ReportFollowUpItem {
  const ReportFollowUpItem({
    required this.kind,
    required this.occurredAt,
    required this.text,
  });

  final StudentRecordEntryKind kind;
  final DateTime occurredAt;
  final String text;
}

final class IndividualReportData {
  const IndividualReportData({
    required this.header,
    required this.student,
    required this.evaluations,
    required this.followUp,
  });

  final ReportHeader header;
  final StudentReportRow student;
  final List<EvaluationReportItem> evaluations;
  final List<ReportFollowUpItem> followUp;
}

final class GroupReportData {
  const GroupReportData({required this.header, required this.students});

  final ReportHeader header;
  final List<StudentReportRow> students;
}
