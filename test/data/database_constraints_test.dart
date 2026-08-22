import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('school year chronology is enforced by SQLite', () async {
    await expectLater(
      database.into(database.schoolYears).insert(
        SchoolYearsCompanion(
          id: const Value('year-invalid'),
          label: const Value('Inválido'),
          startsOn: Value(DateTime(2027, 7, 15)),
          endsOn: Value(DateTime(2026, 8, 31)),
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('group schedules must be complete and inside one day', () async {
    await _seedSchoolYear(database);

    final invalidSchedules = <TeachingGroupsCompanion>[
      const TeachingGroupsCompanion(
        id: Value('group-incomplete'),
        schoolId: Value('school-1'),
        schoolYearId: Value('year-1'),
        name: Value('Horario incompleto'),
        scheduleStartMinutes: Value(480),
      ),
      const TeachingGroupsCompanion(
        id: Value('group-negative'),
        schoolId: Value('school-1'),
        schoolYearId: Value('year-1'),
        name: Value('Horario negativo'),
        scheduleStartMinutes: Value(-1),
        scheduleEndMinutes: Value(600),
      ),
      const TeachingGroupsCompanion(
        id: Value('group-reversed'),
        schoolId: Value('school-1'),
        schoolYearId: Value('year-1'),
        name: Value('Horario invertido'),
        scheduleStartMinutes: Value(600),
        scheduleEndMinutes: Value(600),
      ),
      const TeachingGroupsCompanion(
        id: Value('group-overflow'),
        schoolId: Value('school-1'),
        schoolYearId: Value('year-1'),
        name: Value('Horario fuera del día'),
        scheduleStartMinutes: Value(600),
        scheduleEndMinutes: Value(1440),
      ),
    ];

    for (final companion in invalidSchedules) {
      await expectLater(
        database.into(database.teachingGroups).insert(companion),
        throwsA(isA<Exception>()),
      );
    }
  });

  test('enrollment persistence enforces grade, list number and dates', () async {
    await _seedGroupAndStudent(database);

    await expectLater(
      database.into(database.enrollments).insert(
        EnrollmentsCompanion(
          id: const Value('enrollment-grade'),
          studentId: const Value('student-1'),
          groupId: const Value('group-1'),
          grade: const Value(PrimaryGrade.second),
          listNumber: const Value(1),
          startsOn: Value(DateTime(2026, 8, 31)),
        ),
      ),
      throwsA(isA<Exception>()),
    );

    await expectLater(
      database.into(database.enrollments).insert(
        EnrollmentsCompanion(
          id: const Value('enrollment-list'),
          studentId: const Value('student-1'),
          groupId: const Value('group-1'),
          grade: const Value(PrimaryGrade.first),
          listNumber: const Value(0),
          startsOn: Value(DateTime(2026, 8, 31)),
        ),
      ),
      throwsA(isA<Exception>()),
    );

    await expectLater(
      database.into(database.enrollments).insert(
        EnrollmentsCompanion(
          id: const Value('enrollment-dates'),
          studentId: const Value('student-1'),
          groupId: const Value('group-1'),
          grade: const Value(PrimaryGrade.first),
          listNumber: const Value(1),
          startsOn: Value(DateTime(2026, 9, 2)),
          endsOn: Value(DateTime(2026, 9, 1)),
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('activity roster must stay inside the activity grade scope', () async {
    await _seedActivityContext(database);

    await expectLater(
      database.into(database.activityRoster).insert(
        const ActivityRosterCompanion(
          activityId: Value('activity-1'),
          studentId: Value('student-1'),
          grade: Value(PrimaryGrade.second),
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('activity evaluation requires historical roster membership', () async {
    await _seedActivityContext(database);

    await expectLater(
      database.into(database.activityEvaluations).insert(
        const ActivityEvaluationsCompanion(
          activityId: Value('activity-1'),
          studentId: Value('student-1'),
          deliveryStatus: Value(DeliveryStatus.pending),
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('achievement cannot be persisted for non-delivered work', () async {
    await _seedActivityContext(database);
    await database.into(database.activityRoster).insert(
      const ActivityRosterCompanion(
        activityId: Value('activity-1'),
        studentId: Value('student-1'),
        grade: Value(PrimaryGrade.first),
      ),
    );

    await expectLater(
      database.into(database.activityEvaluations).insert(
        const ActivityEvaluationsCompanion(
          activityId: Value('activity-1'),
          studentId: Value('student-1'),
          deliveryStatus: Value(DeliveryStatus.notDelivered),
          achievement: Value(AchievementLevel.mastered),
        ),
      ),
      throwsA(isA<Exception>()),
    );
  });
}

Future<void> _seedSchoolYear(AppDatabase database) async {
  await database.into(database.schools).insert(
    const SchoolsCompanion(
      id: Value('school-1'),
      name: Value('Escuela de prueba'),
      organization: Value(SchoolOrganization.complete),
    ),
  );
  await database.into(database.schoolYears).insert(
    SchoolYearsCompanion(
      id: const Value('year-1'),
      label: const Value('2026-2027'),
      startsOn: Value(DateTime(2026, 8, 31)),
      endsOn: Value(DateTime(2027, 7, 15)),
    ),
  );
}

Future<void> _seedGroupAndStudent(AppDatabase database) async {
  await _seedSchoolYear(database);
  await database.into(database.teachingGroups).insert(
    const TeachingGroupsCompanion(
      id: Value('group-1'),
      schoolId: Value('school-1'),
      schoolYearId: Value('year-1'),
      name: Value('1.º A'),
    ),
  );
  await database.into(database.groupGrades).insert(
    const GroupGradesCompanion(
      groupId: Value('group-1'),
      grade: Value(PrimaryGrade.first),
    ),
  );
  await database.into(database.students).insert(
    const StudentsCompanion(
      id: Value('student-1'),
      givenNames: Value('Alumno'),
      firstSurname: Value('Demo'),
    ),
  );
}

Future<void> _seedActivityContext(AppDatabase database) async {
  await _seedGroupAndStudent(database);
  await database.into(database.projects).insert(
    const ProjectsCompanion(
      id: Value('project-1'),
      groupId: Value('group-1'),
      title: Value('Proyecto de prueba'),
      lifecycle: Value(ProjectLifecycle.inProgress),
      methodology: Value(ProjectMethodology.communityProjects),
      formativeField: Value(FormativeField.humanAndCommunity),
    ),
  );
  await database.into(database.activities).insert(
    const ActivitiesCompanion(
      id: Value('activity-1'),
      projectId: Value('project-1'),
      title: Value('Actividad de prueba'),
    ),
  );
  await database.into(database.activityGrades).insert(
    const ActivityGradesCompanion(
      activityId: Value('activity-1'),
      grade: Value(PrimaryGrade.first),
    ),
  );
}
