final class GroupExportData {
  const GroupExportData({
    required this.context,
    required this.students,
    required this.attendance,
    required this.projects,
    required this.activities,
    required this.evaluations,
    required this.followUp,
    required this.includeSensitiveFollowUp,
  });

  final GroupExportContextData context;
  final List<GroupExportStudentRow> students;
  final List<GroupExportAttendanceRow> attendance;
  final List<GroupExportProjectRow> projects;
  final List<GroupExportActivityRow> activities;
  final List<GroupExportEvaluationRow> evaluations;
  final List<GroupExportFollowUpRow> followUp;
  final bool includeSensitiveFollowUp;
}

final class GroupExportContextData {
  const GroupExportContextData({
    required this.schoolName,
    required this.schoolYearLabel,
    required this.groupName,
    required this.schoolOrganization,
    required this.grades,
    required this.isMultigrade,
    required this.phases,
    required this.referenceMonth,
    this.cct,
    this.state,
    this.municipality,
    this.locality,
    this.shift,
    this.startsAtMinutes,
    this.endsAtMinutes,
  });

  final String schoolName;
  final String? cct;
  final String? state;
  final String? municipality;
  final String? locality;
  final String schoolOrganization;
  final String schoolYearLabel;
  final String groupName;
  final String? shift;
  final List<int> grades;
  final bool isMultigrade;
  final List<String> phases;
  final int? startsAtMinutes;
  final int? endsAtMinutes;
  final DateTime referenceMonth;
}

final class GroupExportStudentRow {
  const GroupExportStudentRow({
    required this.studentId,
    required this.displayName,
    required this.givenNames,
    required this.firstSurname,
    required this.listNumber,
    required this.grade,
    required this.enrollmentStartsOn,
    required this.isActive,
    this.secondSurname,
    this.sex,
    this.birthDate,
    this.age,
    this.enrollmentEndsOn,
    this.strengths,
    this.difficulties,
    this.supports,
  });

  final String studentId;
  final String displayName;
  final String givenNames;
  final String firstSurname;
  final String? secondSurname;
  final String? sex;
  final DateTime? birthDate;
  final int? age;
  final int listNumber;
  final int grade;
  final DateTime enrollmentStartsOn;
  final DateTime? enrollmentEndsOn;
  final bool isActive;
  final String? strengths;
  final String? difficulties;
  final String? supports;
}

final class GroupExportAttendanceRow {
  const GroupExportAttendanceRow({
    required this.date,
    required this.studentId,
    required this.listNumber,
    required this.studentName,
    required this.grade,
    required this.status,
  });

  final DateTime date;
  final String studentId;
  final int listNumber;
  final String studentName;
  final int grade;
  final String status;
}

final class GroupExportProjectRow {
  const GroupExportProjectRow({
    required this.projectId,
    required this.title,
    required this.lifecycle,
    required this.methodology,
    required this.targetGrades,
    required this.articulatingAxes,
    this.description,
    this.startsOn,
    this.endsOn,
    this.observations,
  });

  final String projectId;
  final String title;
  final String? description;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final String? observations;
  final String lifecycle;
  final String methodology;
  final List<int> targetGrades;
  final List<String> articulatingAxes;
}

final class GroupExportActivityRow {
  const GroupExportActivityRow({
    required this.projectId,
    required this.projectTitle,
    required this.activityId,
    required this.identifier,
    required this.title,
    required this.formativeField,
    required this.targetGrades,
    required this.participantCount,
    this.description,
    this.occursOn,
    this.generalObservations,
  });

  final String projectId;
  final String projectTitle;
  final String activityId;
  final String identifier;
  final String title;
  final String? description;
  final DateTime? occursOn;
  final String? generalObservations;
  final String formativeField;
  final List<int> targetGrades;
  final int participantCount;
}

final class GroupExportEvaluationRow {
  const GroupExportEvaluationRow({
    required this.projectId,
    required this.projectTitle,
    required this.activityId,
    required this.activityIdentifier,
    required this.activityTitle,
    required this.studentId,
    required this.studentName,
    required this.grade,
    required this.resultState,
    required this.deliveryStatus,
    this.activityDate,
    this.listNumber,
    this.achievement,
    this.observation,
  });

  final String projectId;
  final String projectTitle;
  final String activityId;
  final String activityIdentifier;
  final String activityTitle;
  final DateTime? activityDate;
  final String studentId;
  final int? listNumber;
  final String studentName;
  final int grade;
  final String resultState;
  final String deliveryStatus;
  final String? achievement;
  final String? observation;
}

final class GroupExportFollowUpRow {
  const GroupExportFollowUpRow({
    required this.studentId,
    required this.studentName,
    required this.kind,
    required this.occurredAt,
    required this.text,
    this.listNumber,
    this.grade,
  });

  final String studentId;
  final int? listNumber;
  final String studentName;
  final int? grade;
  final String kind;
  final DateTime occurredAt;
  final String text;
}
