import 'dart:convert';

import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/application/automation/automation_service.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _SchoolSetupRepository schoolSetupRepository;
  late _TeachingGroupRepository groupRepository;
  late _StudentRepository studentRepository;
  late TeachingGroup group;
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
    report = _groupReport();
    writes = 0;
  });

  AutomationService buildService() => AutomationService(
    schoolSetupRepository: schoolSetupRepository,
    teachingGroupRepository: groupRepository,
    studentRepository: studentRepository,
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
