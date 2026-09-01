import 'dart:convert';
import 'dart:io';

import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/data/demo/demo_data_seeder.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/data/repositories/drift_activity_repository.dart';
import 'package:aularaiz/data/repositories/drift_attendance_repository.dart';
import 'package:aularaiz/data/repositories/drift_enrollment_repository.dart';
import 'package:aularaiz/data/repositories/drift_project_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/infrastructure/automation/automation_runtime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'aularaiz-agent-mutations-',
    );
    databaseFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}aularaiz-demo.sqlite',
    );

    final database = AppDatabase.forTesting(
      NativeDatabase(databaseFile),
      storageProfile: StorageProfile.demo,
    );
    try {
      await DemoDataSeeder(database).resetAndSeed(now: DateTime(2026, 9, 14));
    } finally {
      await database.close();
    }
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'attendance mutation is dry-run by default and persists on apply',
    () async {
      final runtime = await AutomationRuntime.open(
        databaseFile: databaseFile,
        profile: StorageProfile.demo,
      );
      try {
        final date = DateTime(2026, 9, 21);
        final attendanceRepository = DriftAttendanceRepository(
          runtime.database,
        );

        final preview = await runtime.mutations.setAttendance(
          groupId: DemoDataSeeder.groupId,
          studentId: 'demo-student-ana',
          date: date,
          status: AttendanceStatus.absent,
        );
        expect(preview.data['dry_run'], isTrue);
        expect(preview.data.containsKey('student'), isFalse);
        expect(
          await attendanceRepository.findByGroupAndDate(
            DemoDataSeeder.groupId,
            date,
          ),
          isNull,
        );

        final applied = await runtime.mutations.setAttendance(
          groupId: DemoDataSeeder.groupId,
          studentId: 'demo-student-ana',
          date: date,
          status: AttendanceStatus.absent,
          apply: true,
        );
        expect(applied.data['applied'], isTrue);

        final saved = await attendanceRepository.findByGroupAndDate(
          DemoDataSeeder.groupId,
          date,
        );
        expect(saved?.statusFor('demo-student-ana'), AttendanceStatus.absent);
      } finally {
        await runtime.close();
      }
    },
  );

  test('deactivate and reactivate preserve dry-run/apply boundaries', () async {
    final runtime = await AutomationRuntime.open(
      databaseFile: databaseFile,
      profile: StorageProfile.demo,
    );
    try {
      final enrollmentRepository = DriftEnrollmentRepository(runtime.database);

      final deactivatePreview = await runtime.mutations.deactivateStudent(
        groupId: DemoDataSeeder.groupId,
        studentId: 'demo-student-ana',
        endsOn: DateTime(2026, 9, 30),
      );
      expect(deactivatePreview.data['dry_run'], isTrue);
      var enrollments = await enrollmentRepository.findByStudentId(
        'demo-student-ana',
      );
      expect(enrollments.single.endsOn, isNull);

      final deactivateApplied = await runtime.mutations.deactivateStudent(
        groupId: DemoDataSeeder.groupId,
        studentId: 'demo-student-ana',
        endsOn: DateTime(2026, 9, 30),
        apply: true,
      );
      expect(deactivateApplied.data['applied'], isTrue);
      enrollments = await enrollmentRepository.findByStudentId(
        'demo-student-ana',
      );
      expect(enrollments.single.endsOn, DateTime(2026, 9, 30));

      final reactivatePreview = await runtime.mutations.reactivateStudent(
        groupId: DemoDataSeeder.groupId,
        studentId: 'demo-student-ana',
        grade: PrimaryGrade.fifth,
        listNumber: 1,
      );
      expect(reactivatePreview.data['dry_run'], isTrue);
      expect(reactivatePreview.data['starts_on'], '2026-10-01');
      enrollments = await enrollmentRepository.findByStudentId(
        'demo-student-ana',
      );
      expect(enrollments, hasLength(1));

      final reactivateApplied = await runtime.mutations.reactivateStudent(
        groupId: DemoDataSeeder.groupId,
        studentId: 'demo-student-ana',
        grade: PrimaryGrade.fifth,
        listNumber: 1,
        apply: true,
      );
      expect(reactivateApplied.data['applied'], isTrue);
      enrollments = await enrollmentRepository.findByStudentId(
        'demo-student-ana',
      );
      expect(enrollments, hasLength(2));
      enrollments.sort(
        (left, right) => left.startsOn.compareTo(right.startsOn),
      );
      expect(enrollments.last.startsOn, DateTime(2026, 10, 1));
      expect(enrollments.last.endsOn, isNull);
    } finally {
      await runtime.close();
    }
  });

  test(
    'workspace create is dry-run by default and persists on apply',
    () async {
      final runtime = await AutomationRuntime.open(
        databaseFile: databaseFile,
        profile: StorageProfile.demo,
      );
      try {
        final schoolSetupRepository = DriftSchoolSetupRepository(
          runtime.database,
        );
        expect(await schoolSetupRepository.listSetups(), hasLength(1));

        Future<AutomationEnvelope> run({required bool apply}) {
          return runtime.mutations.createWorkspace(
            schoolName: 'Primaria Nueva',
            organization: SchoolOrganization.complete,
            schoolYearLabel: '2027-2028',
            startsOn: DateTime(2027, 8, 30),
            endsOn: DateTime(2028, 7, 14),
            groupName: '2.º B',
            grades: <PrimaryGrade>{PrimaryGrade.second},
            shift: 'Matutino',
            apply: apply,
          );
        }

        final preview = await run(apply: false);
        expect(preview.data['dry_run'], isTrue);
        expect(await schoolSetupRepository.listSetups(), hasLength(1));

        final applied = await run(apply: true);
        expect(applied.data['applied'], isTrue);

        final setups = await schoolSetupRepository.listSetups();
        expect(setups, hasLength(2));
        final newSetup = setups
            .where((setup) => setup.school.name == 'Primaria Nueva')
            .single;
        final groups = await DriftTeachingGroupRepository(runtime.database)
            .listForSchoolYear(newSetup.schoolYear.id);
        expect(groups.single.name, '2.º B');
      } finally {
        await runtime.close();
      }
    },
  );

  test(
    'school update and delete respect dry-run and apply boundaries',
    () async {
      final runtime = await AutomationRuntime.open(
        databaseFile: databaseFile,
        profile: StorageProfile.demo,
      );
      try {
        final schoolSetupRepository = DriftSchoolSetupRepository(
          runtime.database,
        );

        final preview = await runtime.mutations.updateSchool(
          schoolId: DemoDataSeeder.schoolId,
          name: 'Primaria Renombrada',
          apply: false,
        );
        expect(preview.data['dry_run'], isTrue);
        expect(
          (await schoolSetupRepository.loadForSchool(DemoDataSeeder.schoolId))!
              .school
              .name,
          isNot('Primaria Renombrada'),
        );

        final applied = await runtime.mutations.updateSchool(
          schoolId: DemoDataSeeder.schoolId,
          name: 'Primaria Renombrada',
          apply: true,
        );
        expect(applied.data['applied'], isTrue);
        expect(
          (await schoolSetupRepository.loadForSchool(DemoDataSeeder.schoolId))!
              .school
              .name,
          'Primaria Renombrada',
        );

        final deletePreview = await runtime.mutations.deleteSchool(
          schoolId: DemoDataSeeder.schoolId,
          apply: false,
        );
        expect(deletePreview.data['dry_run'], isTrue);
        expect(
          await schoolSetupRepository.loadForSchool(DemoDataSeeder.schoolId),
          isNotNull,
        );

        final deleteApplied = await runtime.mutations.deleteSchool(
          schoolId: DemoDataSeeder.schoolId,
          apply: true,
        );
        expect(deleteApplied.data['applied'], isTrue);
        expect(
          await schoolSetupRepository.loadForSchool(DemoDataSeeder.schoolId),
          isNull,
        );
      } finally {
        await runtime.close();
      }
    },
  );

  test('group create, update and delete respect dry-run boundaries', () async {
    final runtime = await AutomationRuntime.open(
      databaseFile: databaseFile,
      profile: StorageProfile.demo,
    );
    try {
      final groupRepository = DriftTeachingGroupRepository(runtime.database);

      final preview = await runtime.mutations.createGroup(
        schoolId: DemoDataSeeder.schoolId,
        schoolYearId: DemoDataSeeder.schoolYearId,
        name: '2.º B',
        grades: <PrimaryGrade>{PrimaryGrade.second},
        shift: 'Vespertino',
        apply: false,
      );
      expect(preview.data['dry_run'], isTrue);
      expect(
        await groupRepository.listForSchoolYear(DemoDataSeeder.schoolYearId),
        hasLength(1),
      );

      final applied = await runtime.mutations.createGroup(
        schoolId: DemoDataSeeder.schoolId,
        schoolYearId: DemoDataSeeder.schoolYearId,
        name: '2.º B',
        grades: <PrimaryGrade>{PrimaryGrade.second},
        shift: 'Vespertino',
        apply: true,
      );
      expect(applied.data['applied'], isTrue);
      final groups = await groupRepository.listForSchoolYear(
        DemoDataSeeder.schoolYearId,
      );
      expect(groups, hasLength(2));
      final created = groups.firstWhere((group) => group.name == '2.º B');

      final updatePreview = await runtime.mutations.updateGroup(
        groupId: created.id,
        name: '2.º C',
        grades: <PrimaryGrade>{PrimaryGrade.second},
        apply: false,
      );
      expect(updatePreview.data['dry_run'], isTrue);
      expect((await groupRepository.findById(created.id))!.name, '2.º B');

      await runtime.mutations.updateGroup(
        groupId: created.id,
        name: '2.º C',
        grades: <PrimaryGrade>{PrimaryGrade.second},
        apply: true,
      );
      expect((await groupRepository.findById(created.id))!.name, '2.º C');

      final deletePreview = await runtime.mutations.deleteGroup(
        groupId: created.id,
        apply: false,
      );
      expect(deletePreview.data['dry_run'], isTrue);
      expect(
        await groupRepository.listForSchoolYear(DemoDataSeeder.schoolYearId),
        hasLength(2),
      );

      final deleteApplied = await runtime.mutations.deleteGroup(
        groupId: created.id,
        apply: true,
      );
      expect(deleteApplied.data['applied'], isTrue);
      expect(
        await groupRepository.listForSchoolYear(DemoDataSeeder.schoolYearId),
        hasLength(1),
      );
    } finally {
      await runtime.close();
    }
  });

  test(
    'student create minimizes identity by default and persists on apply',
    () async {
      final runtime = await AutomationRuntime.open(
        databaseFile: databaseFile,
        profile: StorageProfile.demo,
      );
      try {
        final enrollmentRepository = DriftEnrollmentRepository(
          runtime.database,
        );
        final countBefore = (await enrollmentRepository.findByGroupId(
          DemoDataSeeder.groupId,
        )).length;

        final preview = await runtime.mutations.createStudent(
          groupId: DemoDataSeeder.groupId,
          givenNames: 'Nueva',
          firstSurname: 'Alumna',
          grade: PrimaryGrade.fifth,
          listNumber: 13,
        );
        expect(preview.data['dry_run'], isTrue);
        expect(preview.data.containsKey('student'), isFalse);
        expect(jsonEncode(preview.toJson()), isNot(contains('Nueva Alumna')));
        expect(
          (await enrollmentRepository.findByGroupId(DemoDataSeeder.groupId))
              .length,
          countBefore,
        );

        final applied = await runtime.mutations.createStudent(
          groupId: DemoDataSeeder.groupId,
          givenNames: 'Nueva',
          firstSurname: 'Alumna',
          grade: PrimaryGrade.fifth,
          listNumber: 13,
          apply: true,
          privacy: const AutomationPrivacy(includePersonalData: true),
        );
        expect(applied.data['applied'], isTrue);
        expect(jsonEncode(applied.toJson()), contains('Nueva Alumna'));
        expect(
          (await enrollmentRepository.findByGroupId(DemoDataSeeder.groupId))
              .length,
          countBefore + 1,
        );
      } finally {
        await runtime.close();
      }
    },
  );

  test('project and activity mutations respect dry-run boundaries', () async {
    final runtime = await AutomationRuntime.open(
      databaseFile: databaseFile,
      profile: StorageProfile.demo,
    );
    try {
      final projectRepository = DriftProjectRepository(runtime.database);
      final activityRepository = DriftActivityRepository(runtime.database);

      final projectPreview = await runtime.mutations.createProject(
        groupId: DemoDataSeeder.groupId,
        title: 'Proyecto CLI',
        methodology: ProjectMethodology.communityProjects,
        grades: <PrimaryGrade>{PrimaryGrade.fifth},
        apply: false,
      );
      expect(projectPreview.data['dry_run'], isTrue);
      expect(
        await projectRepository.listForGroup(DemoDataSeeder.groupId),
        hasLength(3),
      );

      final projectApplied = await runtime.mutations.createProject(
        groupId: DemoDataSeeder.groupId,
        title: 'Proyecto CLI',
        methodology: ProjectMethodology.communityProjects,
        grades: <PrimaryGrade>{PrimaryGrade.fifth},
        apply: true,
      );
      expect(projectApplied.data['applied'], isTrue);
      final projects = await projectRepository.listForGroup(
        DemoDataSeeder.groupId,
      );
      expect(projects, hasLength(4));
      final created = projects.firstWhere(
        (project) => project.title == 'Proyecto CLI',
      );

      await runtime.mutations.updateProject(
        projectId: created.id,
        title: 'Proyecto CLI Editado',
        methodology: ProjectMethodology.inquirySteam,
        grades: <PrimaryGrade>{PrimaryGrade.fifth},
        apply: true,
      );
      final updatedProjects = await projectRepository.listForGroup(
        DemoDataSeeder.groupId,
      );
      final updated = updatedProjects.firstWhere(
        (project) => project.id == created.id,
      );
      expect(updated.title, 'Proyecto CLI Editado');

      final activityPreview = await runtime.mutations.createActivity(
        projectId: created.id,
        title: 'Actividad CLI',
        formativeField: FormativeField.languages,
        grades: <PrimaryGrade>{PrimaryGrade.fifth},
        occursOn: DateTime(2026, 10, 1),
        apply: false,
      );
      expect(activityPreview.data['dry_run'], isTrue);
      expect(await activityRepository.listForProject(created.id), isEmpty);

      final activityApplied = await runtime.mutations.createActivity(
        projectId: created.id,
        title: 'Actividad CLI',
        formativeField: FormativeField.languages,
        grades: <PrimaryGrade>{PrimaryGrade.fifth},
        occursOn: DateTime(2026, 10, 1),
        apply: true,
      );
      expect(activityApplied.data['applied'], isTrue);
      final activities = await activityRepository.listForProject(created.id);
      expect(activities, hasLength(1));

      final deletePreview = await runtime.mutations.deleteActivity(
        activityId: activities.single.id,
        apply: false,
      );
      expect(deletePreview.data['dry_run'], isTrue);
      expect(await activityRepository.listForProject(created.id), isNotEmpty);

      final deleteApplied = await runtime.mutations.deleteActivity(
        activityId: activities.single.id,
        apply: true,
      );
      expect(deleteApplied.data['applied'], isTrue);
      expect(await activityRepository.listForProject(created.id), isEmpty);
    } finally {
      await runtime.close();
    }
  });

  test('read commands stay minimized without personal-data opt-in', () async {
    final runtime = await AutomationRuntime.open(
      databaseFile: databaseFile,
      profile: StorageProfile.demo,
    );
    try {
      final projects = await runtime.service.listProjects(
        groupId: DemoDataSeeder.groupId,
      );
      expect(projects.kind, 'projects');
      expect(projects.data['project_count'], 3);
      expect(jsonEncode(projects.toJson()), isNot(contains('Ana Sofía')));

      final activities = await runtime.service.listActivities(
        projectId: 'demo-project-community',
      );
      expect(activities.kind, 'activities');
      expect(activities.data['activity_count'], 2);
      expect(jsonEncode(activities.toJson()), isNot(contains('Ana Sofía')));

      final students = await runtime.service.listStudents(
        groupId: DemoDataSeeder.groupId,
      );
      expect(students.kind, 'students');
      expect(students.data['student_count'], 12);
      expect(students.data.containsKey('students'), isFalse);
      expect(jsonEncode(students.toJson()), isNot(contains('Ana Sofía')));
      expect(
        jsonEncode(students.toJson()),
        isNot(contains('demo-student-ana')),
      );

      final personal = await runtime.service.listStudents(
        groupId: DemoDataSeeder.groupId,
        privacy: const AutomationPrivacy(includePersonalData: true),
      );
      final encodedPersonal = jsonEncode(personal.toJson());
      expect(personal.data.containsKey('students'), isTrue);
      expect(encodedPersonal, contains('Ana Sofía'));
    } finally {
      await runtime.close();
    }
  });
}
