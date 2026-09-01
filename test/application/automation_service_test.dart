import 'dart:convert';

import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/application/automation/automation_service.dart';
import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _SchoolSetupRepository schoolSetupRepository;
  late _TeachingGroupRepository groupRepository;
  late _StudentRepository studentRepository;
  late _ProjectRepository projectRepository;
  late _ActivityRepository activityRepository;
  late _EnrollmentRepository enrollmentRepository;
  late TeachingGroup group;
  late Project project;
  late Activity activity;
  late GroupReportData report;
  var writes = 0;

  setUp(() {
    group = TeachingGroup(
      id: 'group-1',
      schoolId: 'school-1',
      schoolYearId: 'year-1',
      name: '3.º A',
      grades: <PrimaryGrade>{PrimaryGrade.third},
      shift: 'Matutino',
    );
    schoolSetupRepository = _SchoolSetupRepository(
      setup: (
        school: School(id: 'school-1', name: 'Escuela de prueba'),
        schoolYear: SchoolYear(
          id: 'year-1',
          label: '2026-2027',
          startsOn: DateTime(2026, 8, 24),
          endsOn: DateTime(2027, 7, 15),
        ),
      ),
    );
    groupRepository = _TeachingGroupRepository(<String, TeachingGroup>{
      group.id: group,
    });
    studentRepository = _StudentRepository(<String, Student>{
      'student-1': Student(
        id: 'student-1',
        givenNames: 'Ana',
        firstSurname: 'Pérez',
      ),
      'student-2': Student(
        id: 'student-2',
        givenNames: 'Luis',
        firstSurname: 'García',
      ),
    });
    project = Project(
      id: 'project-1',
      groupId: group.id,
      title: 'Nuestra comunidad',
      lifecycle: ProjectLifecycle.inProgress,
      methodology: ProjectMethodology.communityProjects,
      targetGrades: <PrimaryGrade>{PrimaryGrade.third},
    );
    activity = Activity(
      id: 'activity-1',
      projectId: project.id,
      title: 'Entrevista comunitaria',
      formativeField: FormativeField.languages,
      occursOn: DateTime(2026, 9, 21),
      targetGrades: <PrimaryGrade>{PrimaryGrade.third},
      roster: const [],
    );
    projectRepository = _ProjectRepository(<String, Project>{
      project.id: project,
    });
    activityRepository = _ActivityRepository(<String, Activity>{
      activity.id: activity,
    });
    enrollmentRepository = _EnrollmentRepository(<String, Enrollment>{
      'enrollment-1': Enrollment(
        id: 'enrollment-1',
        studentId: 'student-1',
        groupId: group.id,
        grade: PrimaryGrade.third,
        listNumber: 1,
        startsOn: DateTime(2026, 8, 1),
      ),
      'enrollment-2': Enrollment(
        id: 'enrollment-2',
        studentId: 'student-2',
        groupId: group.id,
        grade: PrimaryGrade.third,
        listNumber: 2,
        startsOn: DateTime(2026, 8, 1),
        endsOn: DateTime(2026, 8, 15),
      ),
    });
    report = _groupReport();
    writes = 0;
  });

  AutomationService buildService() => AutomationService(
    schoolSetupRepository: schoolSetupRepository,
    teachingGroupRepository: groupRepository,
    studentRepository: studentRepository,
    projectRepository: projectRepository,
    activityRepository: activityRepository,
    enrollmentRepository: enrollmentRepository,
    groupReportLoader: ({required group, required referenceMonth}) async {
      return report;
    },
    studentNoteWriter:
        ({
          required studentId,
          required kind,
          required occurredAt,
          required text,
        }) async {
          writes++;
        },
    clock: () => DateTime.utc(2026, 8, 23, 12),
  );

  test('status exposes capabilities without personal data', () async {
    final result = await buildService().status();
    final encoded = jsonEncode(result.toJson());

    expect(result.kind, 'status');
    expect(result.data['configured'], isTrue);
    expect(result.data['group_count'], 1);
    expect(encoded, isNot(contains('Escuela de prueba')));
    expect(encoded, isNot(contains('Ana Pérez')));
  });

  test('group summary is minimized by default', () async {
    final result = await buildService().groupSummary(
      groupId: group.id,
      referenceMonth: DateTime(2026, 9),
    );
    final encoded = jsonEncode(result.toJson());

    expect(result.privacy.includePersonalData, isFalse);
    expect(result.data['student_count'], 2);
    expect(result.data.containsKey('students'), isFalse);
    expect(encoded, isNot(contains('Ana Pérez')));
    expect(encoded, isNot(contains('student-1')));

    final attendance = result.data['attendance']! as Map<String, Object?>;
    expect(attendance['absent'], 2);
    expect(attendance['present'], 8);
  });

  test('personal group projection requires explicit opt-in', () async {
    final result = await buildService().groupSummary(
      groupId: group.id,
      referenceMonth: DateTime(2026, 9),
      privacy: const AutomationPrivacy(includePersonalData: true),
    );
    final encoded = jsonEncode(result.toJson());

    expect(result.privacy.includePersonalData, isTrue);
    expect(result.data.containsKey('students'), isTrue);
    expect(encoded, contains('Ana Pérez'));
    expect(encoded, contains('student-1'));
  });

  test('recommendations carry evidence but hide targets by default', () async {
    final result = await buildService().recommendations(
      groupId: group.id,
      referenceMonth: DateTime(2026, 9),
    );
    final recommendations =
        result.data['recommendations']! as List<Map<String, Object?>>;
    final encoded = jsonEncode(result.toJson());

    expect(recommendations, isNotEmpty);
    expect(
      recommendations.map((value) => value['code']),
      contains('review-attendance-absences'),
    );
    expect(
      recommendations.every((value) => value.containsKey('evidence')),
      isTrue,
    );
    expect(
      recommendations.every((value) => !value.containsKey('targets')),
      isTrue,
    );
    expect(encoded, isNot(contains('Ana Pérez')));
  });

  test(
    'recommendation targets appear only with personal-data opt-in',
    () async {
      final result = await buildService().recommendations(
        groupId: group.id,
        referenceMonth: DateTime(2026, 9),
        privacy: const AutomationPrivacy(includePersonalData: true),
      );
      final encoded = jsonEncode(result.toJson());

      expect(encoded, contains('targets'));
      expect(encoded, contains('Ana Pérez'));
    },
  );

  test(
    'student note is dry-run by default and never echoes note text',
    () async {
      const secretText = 'Seguimiento privado con la familia';
      final result = await buildService().studentNote(
        studentId: 'student-1',
        kind: StudentRecordEntryKind.familyAgreement,
        occurredAt: DateTime(2026, 9, 5),
        text: secretText,
      );
      final encoded = jsonEncode(result.toJson());

      expect(result.data['dry_run'], isTrue);
      expect(result.data['applied'], isFalse);
      expect(writes, 0);
      expect(encoded, isNot(contains(secretText)));
      expect(encoded, isNot(contains('Ana Pérez')));
    },
  );

  test('student note writes only after explicit apply', () async {
    final result = await buildService().studentNote(
      studentId: 'student-1',
      kind: StudentRecordEntryKind.observation,
      occurredAt: DateTime(2026, 9, 5),
      text: 'Revisar avance lector',
      apply: true,
      privacy: const AutomationPrivacy(includePersonalData: true),
    );

    expect(result.data['dry_run'], isFalse);
    expect(result.data['applied'], isTrue);
    expect(writes, 1);
    expect(jsonEncode(result.toJson()), contains('Ana Pérez'));
  });

  test('projects listing exposes metadata without personal data', () async {
    final result = await buildService().listProjects(groupId: group.id);
    final encoded = jsonEncode(result.toJson());

    expect(result.kind, 'projects');
    expect(result.data['project_count'], 1);
    final projects = result.data['projects']! as List<Map<String, Object?>>;
    expect(projects.single['id'], 'project-1');
    expect(projects.single['title'], 'Nuestra comunidad');
    expect(projects.single['lifecycle'], 'inProgress');
    expect(encoded, isNot(contains('Ana Pérez')));
  });

  test('activities listing exposes metadata for one project', () async {
    final result = await buildService().listActivities(projectId: project.id);
    final encoded = jsonEncode(result.toJson());

    expect(result.kind, 'activities');
    expect(result.data['activity_count'], 1);
    final activities = result.data['activities']! as List<Map<String, Object?>>;
    expect(activities.single['id'], 'activity-1');
    expect(activities.single['occurs_on'], '2026-09-21');
    expect(encoded, isNot(contains('Ana Pérez')));
  });

  test('students listing is minimized by default', () async {
    final result = await buildService().listStudents(groupId: group.id);
    final encoded = jsonEncode(result.toJson());

    expect(result.kind, 'students');
    expect(result.data['student_count'], 2);
    expect(result.data['active_count'], 1);
    expect(result.data['inactive_count'], 1);
    final grades = result.data['enrollment_by_grade']! as Map<String, Object?>;
    expect(grades['3'], 2);
    expect(result.data.containsKey('students'), isFalse);
    expect(encoded, isNot(contains('Ana Pérez')));
    expect(encoded, isNot(contains('student-1')));
    expect(encoded, isNot(contains('Luis')));
  });

  test('students listing requires explicit opt-in for identities', () async {
    final result = await buildService().listStudents(
      groupId: group.id,
      privacy: const AutomationPrivacy(includePersonalData: true),
    );
    final encoded = jsonEncode(result.toJson());

    final students = result.data['students']! as List<Map<String, Object?>>;
    expect(students, hasLength(2));
    expect(students.first['student_id'], 'student-1');
    expect(students.first['name'], 'Ana Pérez');
    expect(students.first['list_number'], 1);
    expect(students.first['active'], isTrue);
    expect(students.last['student_id'], 'student-2');
    expect(students.last['active'], isFalse);
    expect(students.last['ends_on'], '2026-08-15');
    expect(encoded, contains('Ana Pérez'));
  });
}

GroupReportData _groupReport() {
  return GroupReportData(
    header: ReportHeader(
      schoolName: 'Escuela de prueba',
      schoolYearLabel: '2026-2027',
      groupName: '3.º A',
      referenceMonth: DateTime(2026, 9),
    ),
    students: <StudentReportRow>[
      StudentReportRow(
        studentId: 'student-1',
        displayName: 'Ana Pérez',
        listNumber: 1,
        grade: PrimaryGrade.third,
        attendance: const AttendanceReportSummary(
          present: 3,
          absent: 2,
          late: 0,
          justifiedAbsence: 0,
        ),
        evaluation: const EvaluationReportSummary(
          pending: 2,
          delivered: 2,
          notDelivered: 1,
          evaluated: 2,
          mastered: 0,
          sufficient: 1,
          inProgress: 0,
          requiresSupport: 1,
        ),
      ),
      StudentReportRow(
        studentId: 'student-2',
        displayName: 'Luis García',
        listNumber: 2,
        grade: PrimaryGrade.third,
        attendance: const AttendanceReportSummary(
          present: 5,
          absent: 0,
          late: 1,
          justifiedAbsence: 0,
        ),
        evaluation: const EvaluationReportSummary(
          pending: 0,
          delivered: 3,
          notDelivered: 0,
          evaluated: 3,
          mastered: 1,
          sufficient: 2,
          inProgress: 0,
          requiresSupport: 0,
        ),
      ),
    ],
  );
}

final class _SchoolSetupRepository implements SchoolSetupRepository {
  _SchoolSetupRepository({this.setup});

  InitialSchoolSetup? setup;

  @override
  Future<bool> hasInitialSetup() async => setup != null;

  @override
  Future<InitialSchoolSetup?> loadInitialSetup() async => setup;

  @override
  Future<List<InitialSchoolSetup>> listSetups() async =>
      setup == null ? const [] : [setup!];

  @override
  Future<InitialSchoolSetup?> loadForSchool(String schoolId) async {
    final value = setup;
    return value != null && value.school.id == schoolId ? value : null;
  }

  @override
  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  }) async {
    setup = (school: school, schoolYear: schoolYear);
  }
}

final class _TeachingGroupRepository implements TeachingGroupRepository {
  _TeachingGroupRepository(this.groups);

  final Map<String, TeachingGroup> groups;

  @override
  Future<TeachingGroup?> findById(String id) async => groups[id];

  @override
  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId) async {
    return groups.values
        .where((group) => group.schoolYearId == schoolYearId)
        .toList(growable: false);
  }

  @override
  Future<void> save(TeachingGroup group) async {
    groups[group.id] = group;
  }
}

final class _StudentRepository implements StudentRepository {
  _StudentRepository(this.students);

  final Map<String, Student> students;

  @override
  Future<Student?> findById(String id) async => students[id];

  @override
  Future<List<Student>> listAll() async => students.values.toList();

  @override
  Future<void> save(Student student) async {
    students[student.id] = student;
  }
}

final class _ProjectRepository implements ProjectRepository {
  _ProjectRepository(this.projects);

  final Map<String, Project> projects;

  @override
  Future<Project?> findById(String id) async => projects[id];

  @override
  Future<List<Project>> listForGroup(String groupId) async {
    return projects.values
        .where((project) => project.groupId == groupId)
        .toList(growable: false);
  }

  @override
  Future<void> save(Project project) async {
    projects[project.id] = project;
  }
}

final class _ActivityRepository implements ActivityRepository {
  _ActivityRepository(this.activities);

  final Map<String, Activity> activities;

  @override
  Future<Activity?> findById(String id) async => activities[id];

  @override
  Future<List<Activity>> listForProject(String projectId) async {
    return activities.values
        .where((activity) => activity.projectId == projectId)
        .toList(growable: false);
  }

  @override
  Future<void> save(Activity activity) async {
    activities[activity.id] = activity;
  }
}

final class _EnrollmentRepository implements EnrollmentRepository {
  _EnrollmentRepository(this.enrollments);

  final Map<String, Enrollment> enrollments;

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async {
    return enrollments.values
        .where((enrollment) => enrollment.studentId == studentId)
        .toList(growable: false);
  }

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async {
    return enrollments.values
        .where((enrollment) => enrollment.groupId == groupId)
        .toList(growable: false);
  }

  @override
  Future<void> save(Enrollment enrollment) async {
    enrollments[enrollment.id] = enrollment;
  }
}
