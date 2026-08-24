import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/data/repositories/drift_activity_repository.dart';
import 'package:aularaiz/data/repositories/drift_attendance_repository.dart';
import 'package:aularaiz/data/repositories/drift_evaluation_repository.dart';
import 'package:aularaiz/data/repositories/drift_project_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_enrollment_writer.dart';
import 'package:aularaiz/data/repositories/drift_student_record_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:aularaiz/domain/attendance/attendance_entry.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student/student_sex.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';

final class DemoDataSeeder {
  DemoDataSeeder(this.database);

  final AppDatabase database;

  static const schoolId = 'demo-school';
  static const schoolYearId = 'demo-school-year';
  static const groupId = 'demo-group';

  Future<void> ensureSeeded({bool reset = false, DateTime? now}) async {
    if (database.storageProfile != StorageProfile.demo) {
      throw StateError('Demo data can only be written to the demo database.');
    }

    final schoolRepository = DriftSchoolSetupRepository(database);
    if (reset) {
      final setups = await schoolRepository.listSetups();
      for (final setup in setups) {
        await schoolRepository.deleteSchool(setup.school.id);
      }
    }

    if (await schoolRepository.hasInitialSetup()) return;
    await _seed(schoolRepository, now ?? DateTime.now());
  }

  Future<void> _seed(
    DriftSchoolSetupRepository schoolRepository,
    DateTime now,
  ) async {
    final cycleStartYear = now.month >= 8 ? now.year : now.year - 1;
    final startsOn = DateTime(cycleStartYear, 8, 1);
    final endsOn = DateTime(cycleStartYear + 1, 7, 15);

    await schoolRepository.saveInitialSetup(
      school: School(
        id: schoolId,
        name: 'Escuela Primaria Horizonte (DEMO)',
        cct: '27DPR9999D',
        organization: SchoolOrganization.complete,
        state: 'Tabasco',
        municipality: 'Centro',
        locality: 'Villahermosa',
      ),
      schoolYear: SchoolYear(
        id: schoolYearId,
        label: '$cycleStartYear-${cycleStartYear + 1}',
        startsOn: startsOn,
        endsOn: endsOn,
      ),
    );

    final group = TeachingGroup(
      id: groupId,
      schoolId: schoolId,
      schoolYearId: schoolYearId,
      name: '5° A · Grupo de demostración',
      grades: const {PrimaryGrade.fifth},
      shift: 'Matutino',
      schedule: ClassSchedule(startsAtMinutes: 8 * 60, endsAtMinutes: 13 * 60),
    );
    await DriftTeachingGroupRepository(database).save(group);

    final students = _students(cycleStartYear);
    final writer = DriftStudentEnrollmentWriter(database);
    for (var index = 0; index < students.length; index++) {
      final seed = students[index];
      final student = Student(
        id: seed.id,
        givenNames: seed.givenNames,
        firstSurname: seed.firstSurname,
        secondSurname: seed.secondSurname,
        sex: seed.sex,
        birthDate: seed.birthDate,
      );
      await writer.saveNewStudentWithEnrollment(
        student: student,
        enrollment: Enrollment(
          id: 'demo-enrollment-${index + 1}',
          studentId: student.id,
          groupId: groupId,
          grade: PrimaryGrade.fifth,
          listNumber: index + 1,
          startsOn: startsOn,
        ),
      );
    }

    await _seedAttendance(students, startsOn, now);
    await _seedProjectsAndEvaluations(students, startsOn, now);
    await _seedStudentRecords(students, now);
  }

  Future<void> _seedAttendance(
    List<_DemoStudentSeed> students,
    DateTime startsOn,
    DateTime now,
  ) async {
    final repository = DriftAttendanceRepository(database);
    final days = _recentSchoolDays(now, startsOn, 10);

    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final entries = <AttendanceEntry>[];
      for (var studentIndex = 0; studentIndex < students.length; studentIndex++) {
        final marker = (dayIndex * 3 + studentIndex) % 19;
        final status = switch (marker) {
          0 => AttendanceStatus.absent,
          4 => AttendanceStatus.late,
          9 => AttendanceStatus.justifiedAbsence,
          _ => AttendanceStatus.present,
        };
        entries.add(
          AttendanceEntry(studentId: students[studentIndex].id, status: status),
        );
      }
      await repository.save(
        DailyAttendance(
          id: 'demo-attendance-${dayIndex + 1}',
          groupId: groupId,
          date: days[dayIndex],
          entries: entries,
        ),
      );
    }
  }

  Future<void> _seedProjectsAndEvaluations(
    List<_DemoStudentSeed> students,
    DateTime startsOn,
    DateTime now,
  ) async {
    final projectRepository = DriftProjectRepository(database);
    final activityRepository = DriftActivityRepository(database);
    final evaluationRepository = DriftEvaluationRepository(database);

    final projects = <Project>[
      Project(
        id: 'demo-project-community',
        groupId: groupId,
        title: 'Nuestra comunidad, nuestras propuestas',
        lifecycle: ProjectLifecycle.inProgress,
        methodology: ProjectMethodology.communityProjects,
        articulatingAxes: const {
          ArticulatingAxis.inclusion,
          ArticulatingAxis.criticalThinking,
          ArticulatingAxis.culturesThroughReadingAndWriting,
        },
        targetGrades: const {PrimaryGrade.fifth},
      ),
      Project(
        id: 'demo-project-water',
        groupId: groupId,
        title: 'Guardianes del agua',
        lifecycle: ProjectLifecycle.completed,
        methodology: ProjectMethodology.inquirySteam,
        articulatingAxes: const {
          ArticulatingAxis.healthyLife,
          ArticulatingAxis.criticalThinking,
        },
        targetGrades: const {PrimaryGrade.fifth},
      ),
      Project(
        id: 'demo-project-reading',
        groupId: groupId,
        title: 'Historias que nos representan',
        lifecycle: ProjectLifecycle.draft,
        methodology: ProjectMethodology.serviceLearning,
        articulatingAxes: const {
          ArticulatingAxis.criticalInterculturality,
          ArticulatingAxis.artsAndAestheticExperiences,
        },
        targetGrades: const {PrimaryGrade.fifth},
      ),
    ];
    for (final project in projects) {
      await projectRepository.save(project);
    }

    final roster = [
      for (final student in students)
        ActivityParticipant(studentId: student.id, grade: PrimaryGrade.fifth),
    ];
    final activities = <Activity>[
      Activity(
        id: 'demo-activity-map',
        projectId: projects[0].id,
        identifier: 'COM-01',
        title: 'Mapa de necesidades de la comunidad',
        occursOn: _notBefore(startsOn, now.subtract(const Duration(days: 14))),
        formativeField: FormativeField.humanAndCommunity,
        targetGrades: const {PrimaryGrade.fifth},
        roster: roster,
      ),
      Activity(
        id: 'demo-activity-interview',
        projectId: projects[0].id,
        identifier: 'COM-02',
        title: 'Entrevista a una persona de la comunidad',
        occursOn: _notBefore(startsOn, now.subtract(const Duration(days: 7))),
        formativeField: FormativeField.languages,
        targetGrades: const {PrimaryGrade.fifth},
        roster: roster,
      ),
      Activity(
        id: 'demo-activity-water-log',
        projectId: projects[1].id,
        identifier: 'AGUA-01',
        title: 'Registro del consumo de agua',
        occursOn: _notBefore(startsOn, now.subtract(const Duration(days: 10))),
        formativeField: FormativeField.knowledgeAndScientificThought,
        targetGrades: const {PrimaryGrade.fifth},
        roster: roster,
      ),
      Activity(
        id: 'demo-activity-water-proposals',
        projectId: projects[1].id,
        identifier: 'AGUA-02',
        title: 'Propuestas para cuidar el agua',
        occursOn: _notBefore(startsOn, now.subtract(const Duration(days: 3))),
        formativeField: FormativeField.ethicsNatureAndSocieties,
        targetGrades: const {PrimaryGrade.fifth},
        roster: roster,
      ),
    ];
    for (final activity in activities) {
      await activityRepository.save(activity);
    }

    final achievements = AchievementLevel.values;
    for (var activityIndex = 0; activityIndex < activities.length; activityIndex++) {
      for (var studentIndex = 0; studentIndex < students.length; studentIndex++) {
        final marker = activityIndex * students.length + studentIndex;
        if (marker % 6 == 0) continue;

        final student = students[studentIndex];
        if (marker % 11 == 0) {
          await evaluationRepository.save(
            ActivityEvaluation(
              activityId: activities[activityIndex].id,
              studentId: student.id,
              deliveryStatus: DeliveryStatus.notDelivered,
              observation: 'Requiere acordar una nueva fecha de entrega.',
            ),
          );
          continue;
        }

        await evaluationRepository.save(
          ActivityEvaluation(
            activityId: activities[activityIndex].id,
            studentId: student.id,
            deliveryStatus: DeliveryStatus.delivered,
            achievement: achievements[marker % achievements.length],
            observation: marker % 4 == 0
                ? 'Explica sus decisiones y mejora a partir de la retroalimentación.'
                : null,
          ),
        );
      }
    }
  }

  Future<void> _seedStudentRecords(
    List<_DemoStudentSeed> students,
    DateTime now,
  ) async {
    final repository = DriftStudentRecordRepository(database);
    final records = <StudentRecord>[
      StudentRecord(
        studentId: students[0].id,
        strengths: 'Participa con iniciativa y comunica sus ideas con claridad.',
        difficulties: 'Necesita organizar mejor los pasos de tareas extensas.',
        supports: 'Usar listas breves de verificación y ejemplos resueltos.',
      ),
      StudentRecord(
        studentId: students[1].id,
        strengths: 'Relaciona datos y propone explicaciones fundamentadas.',
        difficulties: 'Le cuesta pedir ayuda cuando encuentra un obstáculo.',
        supports: 'Acordar pausas de revisión durante el trabajo independiente.',
      ),
      StudentRecord(
        studentId: students[2].id,
        strengths: 'Colabora de forma respetuosa y escucha otros puntos de vista.',
        difficulties: 'Requiere mayor seguridad al presentar frente al grupo.',
        supports: 'Preparar exposiciones cortas en pareja antes de plenaria.',
      ),
      StudentRecord(
        studentId: students[3].id,
        strengths: 'Lee con fluidez y recupera información relevante.',
        difficulties: 'Debe justificar con mayor detalle sus conclusiones.',
        supports: 'Usar preguntas guía: qué, cómo y por qué.',
      ),
    ];

    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      await repository.save(record);
      await repository.addEntry(
        StudentRecordEntry(
          id: 'demo-record-observation-${index + 1}',
          studentId: record.studentId,
          kind: StudentRecordEntryKind.observation,
          occurredAt: now.subtract(Duration(days: 8 - index)),
          text: 'Observación ficticia de demostración: mostró avances durante el trabajo por proyecto.',
        ),
      );
      if (index < 2) {
        await repository.addEntry(
          StudentRecordEntry(
            id: 'demo-record-agreement-${index + 1}',
            studentId: record.studentId,
            kind: StudentRecordEntryKind.familyAgreement,
            occurredAt: now.subtract(Duration(days: 5 - index)),
            text: 'Acuerdo ficticio de demostración: revisar una actividad breve en casa dos veces por semana.',
          ),
        );
      }
    }
  }

  List<DateTime> _recentSchoolDays(DateTime now, DateTime startsOn, int count) {
    final result = <DateTime>[];
    var cursor = DateTime(now.year, now.month, now.day);
    while (result.length < count && !cursor.isBefore(startsOn)) {
      if (cursor.weekday != DateTime.saturday &&
          cursor.weekday != DateTime.sunday) {
        result.add(cursor);
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    result.sort();
    return result;
  }

  DateTime _notBefore(DateTime startsOn, DateTime candidate) {
    final value = DateTime(candidate.year, candidate.month, candidate.day);
    return value.isBefore(startsOn) ? startsOn : value;
  }

  List<_DemoStudentSeed> _students(int cycleStartYear) {
    final birthYear = cycleStartYear - 11;
    return <_DemoStudentSeed>[
      _DemoStudentSeed('demo-student-01', 'Ana Sofía', 'García', 'López', StudentSex.female, DateTime(birthYear, 2, 14)),
      _DemoStudentSeed('demo-student-02', 'Mateo', 'Hernández', 'Cruz', StudentSex.male, DateTime(birthYear, 5, 3)),
      _DemoStudentSeed('demo-student-03', 'Valentina', 'Pérez', 'Sánchez', StudentSex.female, DateTime(birthYear, 8, 21)),
      _DemoStudentSeed('demo-student-04', 'Emiliano', 'Martínez', 'Torres', StudentSex.male, DateTime(birthYear, 11, 9)),
      _DemoStudentSeed('demo-student-05', 'Camila', 'Jiménez', 'Gómez', StudentSex.female, DateTime(birthYear, 1, 28)),
      _DemoStudentSeed('demo-student-06', 'Santiago', 'Morales', 'Díaz', StudentSex.male, DateTime(birthYear, 4, 17)),
      _DemoStudentSeed('demo-student-07', 'Ximena', 'Ramírez', 'Ortiz', StudentSex.female, DateTime(birthYear, 7, 6)),
      _DemoStudentSeed('demo-student-08', 'Leonardo', 'Castillo', 'Reyes', StudentSex.male, DateTime(birthYear, 10, 24)),
      _DemoStudentSeed('demo-student-09', 'Regina', 'Vázquez', 'Méndez', StudentSex.female, DateTime(birthYear, 3, 12)),
      _DemoStudentSeed('demo-student-10', 'Diego', 'Flores', 'Aguilar', StudentSex.male, DateTime(birthYear, 6, 30)),
      _DemoStudentSeed('demo-student-11', 'Renata', 'Domínguez', 'Ramos', StudentSex.female, DateTime(birthYear, 9, 15)),
      _DemoStudentSeed('demo-student-12', 'Sebastián', 'Navarro', 'Ruiz', StudentSex.male, DateTime(birthYear, 12, 2)),
    ];
  }
}

final class _DemoStudentSeed {
  const _DemoStudentSeed(
    this.id,
    this.givenNames,
    this.firstSurname,
    this.secondSurname,
    this.sex,
    this.birthDate,
  );

  final String id;
  final String givenNames;
  final String firstSurname;
  final String secondSurname;
  final StudentSex sex;
  final DateTime birthDate;
}
