import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/application/reports/report_projection_builder.dart';
import 'package:aularaiz/domain/attendance/attendance_entry.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late School school;
  late SchoolYear schoolYear;
  late TeachingGroup group;
  late Student ana;
  late Student bruno;
  late Enrollment anaEnrollment;
  late Enrollment brunoEnrollment;
  late Project project;
  late Activity activity;
  late ReportProjectionBuilder builder;

  setUp(() {
    school = School(
      id: 'school-1',
      name: 'Primaria de Prueba',
      cct: '27DPR0000X',
    );
    schoolYear = SchoolYear(
      id: 'year-1',
      label: '2026-2027',
      startsOn: DateTime(2026, 8, 1),
      endsOn: DateTime(2027, 7, 31),
    );
    group = TeachingGroup(
      id: 'group-1',
      schoolId: school.id,
      schoolYearId: schoolYear.id,
      name: '5° A',
      grades: {PrimaryGrade.fifth},
    );
    ana = Student(id: 'student-ana', givenNames: 'Ana', firstSurname: 'López');
    bruno = Student(
      id: 'student-bruno',
      givenNames: 'Bruno',
      firstSurname: 'Pérez',
    );
    anaEnrollment = Enrollment(
      id: 'enrollment-ana',
      studentId: ana.id,
      groupId: group.id,
      grade: PrimaryGrade.fifth,
      listNumber: 1,
      startsOn: DateTime(2026, 8, 1),
    );
    brunoEnrollment = Enrollment(
      id: 'enrollment-bruno',
      studentId: bruno.id,
      groupId: group.id,
      grade: PrimaryGrade.fifth,
      listNumber: 2,
      startsOn: DateTime(2026, 8, 1),
      endsOn: DateTime(2026, 8, 15),
    );
    project = Project(
      id: 'project-1',
      groupId: group.id,
      title: 'Lectura comunitaria',
      lifecycle: ProjectLifecycle.inProgress,
      methodology: ProjectMethodology.communityProjects,
      formativeFields: {FormativeField.languages},
      targetGrades: {PrimaryGrade.fifth},
    );
    activity = Activity(
      id: 'activity-1',
      projectId: project.id,
      title: 'Comprensión del cuento',
      formativeField: FormativeField.languages,
      targetGrades: {PrimaryGrade.fifth},
      roster: [
        ActivityParticipant(studentId: ana.id, grade: PrimaryGrade.fifth),
        ActivityParticipant(studentId: bruno.id, grade: PrimaryGrade.fifth),
      ],
    );

    final attendance = DailyAttendance(
      id: 'attendance-1',
      groupId: group.id,
      date: DateTime(2026, 8, 5),
      entries: [
        AttendanceEntry(studentId: ana.id, status: AttendanceStatus.present),
        AttendanceEntry(studentId: bruno.id, status: AttendanceStatus.absent),
      ],
    );
    final anaEvaluation = ActivityEvaluation(
      activityId: activity.id,
      studentId: ana.id,
      deliveryStatus: DeliveryStatus.delivered,
      achievement: AchievementLevel.sufficient,
      observation: 'Dato sensible de evaluación',
    );
    final anaRecord = StudentRecord(
      studentId: ana.id,
      strengths: 'Fortaleza sensible',
      difficulties: 'Dificultad sensible',
      supports: 'Apoyo sensible',
    );
    final anaEntry = StudentRecordEntry(
      id: 'entry-1',
      studentId: ana.id,
      kind: StudentRecordEntryKind.familyAgreement,
      occurredAt: DateTime.utc(2026, 8, 10),
      text: 'Acuerdo familiar sensible',
    );

    builder = ReportProjectionBuilder(
      schoolSetupRepository: _SchoolSetupRepository(school, schoolYear),
      enrollmentRepository: _EnrollmentRepository([
        anaEnrollment,
        brunoEnrollment,
      ]),
      studentRepository: _StudentRepository([ana, bruno]),
      attendanceRepository: _AttendanceRepository([attendance]),
      projectRepository: _ProjectRepository([project]),
      activityRepository: _ActivityRepository([activity]),
      evaluationRepository: _EvaluationRepository([anaEvaluation]),
      studentRecordRepository: _StudentRecordRepository(
        records: [anaRecord],
        entries: [anaEntry],
      ),
    );
  });

  test(
    'excludes sensitive follow-up from individual report by default',
    () async {
      final report = await builder.buildIndividual(
        group: group,
        studentId: ana.id,
        referenceMonth: DateTime(2026, 8),
      );

      expect(report.student.strengths, isNull);
      expect(report.student.difficulties, isNull);
      expect(report.student.supports, isNull);
      expect(report.followUp, isEmpty);
      expect(report.evaluations.single.observation, isNull);
      expect(report.student.attendance.present, 1);
      expect(report.student.evaluation.delivered, 1);
      expect(report.student.evaluation.sufficient, 1);
    },
  );

  test('includes sensitive follow-up only after explicit opt-in', () async {
    final report = await builder.buildIndividual(
      group: group,
      studentId: ana.id,
      referenceMonth: DateTime(2026, 8),
      privacy: const ReportPrivacyOptions(includeSensitiveFollowUp: true),
    );

    expect(report.student.strengths, 'Fortaleza sensible');
    expect(report.student.difficulties, 'Dificultad sensible');
    expect(report.student.supports, 'Apoyo sensible');
    expect(report.followUp.single.text, 'Acuerdo familiar sensible');
    expect(
      report.evaluations.single.observation,
      'Dato sensible de evaluación',
    );
  });

  test(
    'keeps mid-month historical enrollment and counts unsaved evaluation as pending',
    () async {
      final report = await builder.buildGroup(
        group: group,
        referenceMonth: DateTime(2026, 8),
      );

      expect(report.students.map((student) => student.studentId), [
        ana.id,
        bruno.id,
      ]);
      final historical = report.students.singleWhere(
        (student) => student.studentId == bruno.id,
      );
      expect(historical.attendance.absent, 1);
      expect(historical.evaluation.pending, 1);
      expect(historical.evaluation.notDelivered, 0);
      expect(historical.evaluation.evaluated, 0);
    },
  );

  test('excludes enrollment after its historical month ends', () async {
    final report = await builder.buildGroup(
      group: group,
      referenceMonth: DateTime(2026, 9),
    );

    expect(report.students.map((student) => student.studentId), [ana.id]);
  });
}

final class _SchoolSetupRepository implements SchoolSetupRepository {
  _SchoolSetupRepository(this.school, this.schoolYear);

  final School school;
  final SchoolYear schoolYear;

  InitialSchoolSetup get _setup => (school: school, schoolYear: schoolYear);

  @override
  Future<bool> hasInitialSetup() async => true;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async => _setup;

  @override
  Future<List<InitialSchoolSetup>> listSetups() async => [_setup];

  @override
  Future<InitialSchoolSetup?> loadForSchool(String schoolId) async =>
      schoolId == school.id ? _setup : null;

  @override
  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  }) async {}
}

final class _EnrollmentRepository implements EnrollmentRepository {
  _EnrollmentRepository(this.values);

  final List<Enrollment> values;

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async =>
      values.where((value) => value.groupId == groupId).toList();

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async =>
      values.where((value) => value.studentId == studentId).toList();

  @override
  Future<void> save(Enrollment enrollment) async {}
}

final class _StudentRepository implements StudentRepository {
  _StudentRepository(this.values);

  final List<Student> values;

  @override
  Future<Student?> findById(String id) async {
    for (final student in values) {
      if (student.id == id) return student;
    }
    return null;
  }

  @override
  Future<List<Student>> listAll() async => List<Student>.of(values);

  @override
  Future<void> save(Student student) async {}
}

final class _AttendanceRepository implements AttendanceRepository {
  _AttendanceRepository(this.values);

  final List<DailyAttendance> values;

  @override
  Future<DailyAttendance?> findByGroupAndDate(
    String groupId,
    DateTime date,
  ) async {
    for (final attendance in values) {
      if (attendance.groupId == groupId &&
          attendance.date.year == date.year &&
          attendance.date.month == date.month &&
          attendance.date.day == date.day) {
        return attendance;
      }
    }
    return null;
  }

  @override
  Future<List<DailyAttendance>> listForMonth(
    String groupId,
    DateTime month,
  ) async {
    return values
        .where(
          (attendance) =>
              attendance.groupId == groupId &&
              attendance.date.year == month.year &&
              attendance.date.month == month.month,
        )
        .toList();
  }

  @override
  Future<void> save(DailyAttendance attendance) async {}
}

final class _ProjectRepository implements ProjectRepository {
  _ProjectRepository(this.values);

  final List<Project> values;

  @override
  Future<Project?> findById(String id) async {
    for (final project in values) {
      if (project.id == id) return project;
    }
    return null;
  }

  @override
  Future<List<Project>> listForGroup(String groupId) async =>
      values.where((value) => value.groupId == groupId).toList();

  @override
  Future<void> save(Project project) async {}
}

final class _ActivityRepository implements ActivityRepository {
  _ActivityRepository(this.values);

  final List<Activity> values;

  @override
  Future<Activity?> findById(String id) async {
    for (final activity in values) {
      if (activity.id == id) return activity;
    }
    return null;
  }

  @override
  Future<List<Activity>> listForProject(String projectId) async =>
      values.where((value) => value.projectId == projectId).toList();

  @override
  Future<void> save(Activity activity) async {}
}

final class _EvaluationRepository implements EvaluationRepository {
  _EvaluationRepository(this.values);

  final List<ActivityEvaluation> values;

  @override
  Future<ActivityEvaluation?> find(String activityId, String studentId) async {
    for (final evaluation in values) {
      if (evaluation.activityId == activityId &&
          evaluation.studentId == studentId) {
        return evaluation;
      }
    }
    return null;
  }

  @override
  Future<List<ActivityEvaluation>> listForActivity(String activityId) async =>
      values.where((value) => value.activityId == activityId).toList();

  @override
  Future<List<ActivityEvaluation>> listForStudent(String studentId) async =>
      values.where((value) => value.studentId == studentId).toList();

  @override
  Future<void> save(ActivityEvaluation evaluation) async {}
}

final class _StudentRecordRepository implements StudentRecordRepository {
  _StudentRecordRepository({required this.records, required this.entries});

  final List<StudentRecord> records;
  final List<StudentRecordEntry> entries;

  @override
  Future<StudentRecord?> find(String studentId) async {
    for (final record in records) {
      if (record.studentId == studentId) return record;
    }
    return null;
  }

  @override
  Future<List<StudentRecordEntry>> listEntries(String studentId) async =>
      entries.where((entry) => entry.studentId == studentId).toList();

  @override
  Future<void> save(StudentRecord record) async {}

  @override
  Future<void> addEntry(StudentRecordEntry entry) async {}
}
