import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:drift/drift.dart';

final class DemoDataSeeder {
  DemoDataSeeder(this.database);

  final AppDatabase database;

  Future<void> seedIfEmpty() async {
    _requireDemoProfile();
    final schools = await database.select(database.schools).get();
    if (schools.isNotEmpty) return;

    await database.transaction(_seedFixture);
  }

  Future<void> resetAndSeed() async {
    _requireDemoProfile();
    await database.transaction(() async {
      await _clearAll();
      await _seedFixture();
    });
  }

  void _requireDemoProfile() {
    if (database.storageProfile != StorageProfile.demo) {
      throw StateError(
        'Demo data can only be changed through a demo-profile database.',
      );
    }
  }

  Future<void> _clearAll() async {
    await database.delete(database.studentRecordEntries).go();
    await database.delete(database.studentRecords).go();
    await database.delete(database.activityEvaluations).go();
    await database.delete(database.activityRoster).go();
    await database.delete(database.activityGrades).go();
    await database.delete(database.activities).go();
    await database.delete(database.projectGrades).go();
    await database.delete(database.projects).go();
    await database.delete(database.attendanceEntries).go();
    await database.delete(database.attendanceDays).go();
    await database.delete(database.enrollments).go();
    await database.delete(database.students).go();
    await database.delete(database.groupGrades).go();
    await database.delete(database.teachingGroups).go();
    await database.delete(database.schoolYears).go();
    await database.delete(database.schools).go();
  }

  Future<void> _seedFixture() async {
    await database
        .into(database.schools)
        .insert(
          const SchoolsCompanion(
            id: Value('demo-school'),
            name: Value('Escuela Primaria Amanecer (Demo)'),
            organization: Value(SchoolOrganization.twoTeacher),
            state: Value('Tabasco'),
            municipality: Value('Municipio de demostración'),
            locality: Value('Localidad de demostración'),
          ),
        );
    await database
        .into(database.schoolYears)
        .insert(
          SchoolYearsCompanion(
            id: const Value('demo-year-2026'),
            label: const Value('2026-2027'),
            startsOn: Value(DateTime(2026, 8, 31)),
            endsOn: Value(DateTime(2027, 7, 15)),
          ),
        );
    await database
        .into(database.teachingGroups)
        .insert(
          const TeachingGroupsCompanion(
            id: Value('demo-group'),
            schoolId: Value('demo-school'),
            schoolYearId: Value('demo-year-2026'),
            name: Value('1.º y 2.º A (Demo)'),
            shift: Value('Matutino'),
            scheduleStartMinutes: Value(480),
            scheduleEndMinutes: Value(780),
          ),
        );
    await database
        .into(database.groupGrades)
        .insert(
          const GroupGradesCompanion(
            groupId: Value('demo-group'),
            grade: Value(PrimaryGrade.first),
          ),
        );
    await database
        .into(database.groupGrades)
        .insert(
          const GroupGradesCompanion(
            groupId: Value('demo-group'),
            grade: Value(PrimaryGrade.second),
          ),
        );

    await database
        .into(database.students)
        .insert(
          StudentsCompanion(
            id: const Value('demo-student-ana'),
            givenNames: const Value('Ana'),
            firstSurname: const Value('Solís'),
            birthDate: Value(DateTime(2019, 2, 10)),
          ),
        );
    await database
        .into(database.students)
        .insert(
          StudentsCompanion(
            id: const Value('demo-student-bruno'),
            givenNames: const Value('Bruno'),
            firstSurname: const Value('Méndez'),
            birthDate: Value(DateTime(2018, 11, 22)),
          ),
        );
    await database
        .into(database.students)
        .insert(
          StudentsCompanion(
            id: const Value('demo-student-carla'),
            givenNames: const Value('Carla'),
            firstSurname: const Value('Ruiz'),
            birthDate: Value(DateTime(2019, 6, 15)),
          ),
        );

    await database
        .into(database.enrollments)
        .insert(
          EnrollmentsCompanion(
            id: const Value('demo-enrollment-ana'),
            studentId: const Value('demo-student-ana'),
            groupId: const Value('demo-group'),
            grade: const Value(PrimaryGrade.first),
            listNumber: const Value(1),
            startsOn: Value(DateTime(2026, 8, 31)),
          ),
        );
    await database
        .into(database.enrollments)
        .insert(
          EnrollmentsCompanion(
            id: const Value('demo-enrollment-bruno'),
            studentId: const Value('demo-student-bruno'),
            groupId: const Value('demo-group'),
            grade: const Value(PrimaryGrade.second),
            listNumber: const Value(2),
            startsOn: Value(DateTime(2026, 8, 31)),
          ),
        );
    await database
        .into(database.enrollments)
        .insert(
          EnrollmentsCompanion(
            id: const Value('demo-enrollment-carla'),
            studentId: const Value('demo-student-carla'),
            groupId: const Value('demo-group'),
            grade: const Value(PrimaryGrade.first),
            listNumber: const Value(3),
            startsOn: Value(DateTime(2026, 8, 31)),
          ),
        );

    await database
        .into(database.attendanceDays)
        .insert(
          AttendanceDaysCompanion(
            id: const Value('demo-attendance-2026-09-03'),
            groupId: const Value('demo-group'),
            date: Value(DateTime(2026, 9, 3)),
          ),
        );
    await database
        .into(database.attendanceEntries)
        .insert(
          const AttendanceEntriesCompanion(
            attendanceDayId: Value('demo-attendance-2026-09-03'),
            studentId: Value('demo-student-ana'),
            status: Value(AttendanceStatus.present),
          ),
        );
    await database
        .into(database.attendanceEntries)
        .insert(
          const AttendanceEntriesCompanion(
            attendanceDayId: Value('demo-attendance-2026-09-03'),
            studentId: Value('demo-student-bruno'),
            status: Value(AttendanceStatus.late),
          ),
        );
    await database
        .into(database.attendanceEntries)
        .insert(
          const AttendanceEntriesCompanion(
            attendanceDayId: Value('demo-attendance-2026-09-03'),
            studentId: Value('demo-student-carla'),
            status: Value(AttendanceStatus.justifiedAbsence),
          ),
        );

    await database
        .into(database.projects)
        .insert(
          const ProjectsCompanion(
            id: Value('demo-project-community'),
            groupId: Value('demo-group'),
            title: Value('Nuestro entorno escolar'),
            lifecycle: Value(ProjectLifecycle.inProgress),
            methodology: Value(ProjectMethodology.communityProjects),
            formativeField: Value(FormativeField.humanAndCommunity),
          ),
        );
    await database
        .into(database.projectGrades)
        .insert(
          const ProjectGradesCompanion(
            projectId: Value('demo-project-community'),
            grade: Value(PrimaryGrade.first),
          ),
        );
    await database
        .into(database.projectGrades)
        .insert(
          const ProjectGradesCompanion(
            projectId: Value('demo-project-community'),
            grade: Value(PrimaryGrade.second),
          ),
        );
    await database
        .into(database.activities)
        .insert(
          const ActivitiesCompanion(
            id: Value('demo-activity-map'),
            projectId: Value('demo-project-community'),
            title: Value('Mapa de nuestra comunidad'),
          ),
        );
    await database
        .into(database.activityGrades)
        .insert(
          const ActivityGradesCompanion(
            activityId: Value('demo-activity-map'),
            grade: Value(PrimaryGrade.first),
          ),
        );
    await database
        .into(database.activityGrades)
        .insert(
          const ActivityGradesCompanion(
            activityId: Value('demo-activity-map'),
            grade: Value(PrimaryGrade.second),
          ),
        );

    await _insertActivityParticipant(
      studentId: 'demo-student-ana',
      grade: PrimaryGrade.first,
      deliveryStatus: DeliveryStatus.delivered,
      achievement: AchievementLevel.mastered,
    );
    await _insertActivityParticipant(
      studentId: 'demo-student-bruno',
      grade: PrimaryGrade.second,
      deliveryStatus: DeliveryStatus.delivered,
      achievement: AchievementLevel.inProgress,
      observation: 'Explica sus hallazgos y continúa afinando la organización.',
    );
    await _insertActivityParticipant(
      studentId: 'demo-student-carla',
      grade: PrimaryGrade.first,
      deliveryStatus: DeliveryStatus.notDelivered,
    );

    await database
        .into(database.studentRecords)
        .insert(
          const StudentRecordsCompanion(
            studentId: Value('demo-student-ana'),
            strengths: Value(
              'Participa con iniciativa en actividades colaborativas.',
            ),
            difficulties: Value(
              'Requiere tiempo adicional para organizar textos largos.',
            ),
            supports: Value('Consignas breves y organizadores visuales.'),
          ),
        );
    await database
        .into(database.studentRecordEntries)
        .insert(
          StudentRecordEntriesCompanion(
            id: const Value('demo-record-observation-1'),
            studentId: const Value('demo-student-ana'),
            kind: const Value(StudentRecordEntryKind.observation),
            occurredAt: Value(DateTime(2026, 9, 3)),
            content: const Value(
              'Participó activamente en la construcción del mapa comunitario.',
            ),
          ),
        );
    await database
        .into(database.studentRecordEntries)
        .insert(
          StudentRecordEntriesCompanion(
            id: const Value('demo-record-agreement-1'),
            studentId: const Value('demo-student-ana'),
            kind: const Value(StudentRecordEntryKind.familyAgreement),
            occurredAt: Value(DateTime(2026, 9, 5)),
            content: const Value(
              'Familia y docente acuerdan mantener una rutina breve de lectura.',
            ),
          ),
        );
  }

  Future<void> _insertActivityParticipant({
    required String studentId,
    required PrimaryGrade grade,
    required DeliveryStatus deliveryStatus,
    AchievementLevel? achievement,
    String? observation,
  }) async {
    await database
        .into(database.activityRoster)
        .insert(
          ActivityRosterCompanion(
            activityId: const Value('demo-activity-map'),
            studentId: Value(studentId),
            grade: Value(grade),
          ),
        );
    await database
        .into(database.activityEvaluations)
        .insert(
          ActivityEvaluationsCompanion(
            activityId: const Value('demo-activity-map'),
            studentId: Value(studentId),
            deliveryStatus: Value(deliveryStatus),
            achievement: Value(achievement),
            observation: Value(observation),
          ),
        );
  }
}
