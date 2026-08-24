import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/student/student_sex.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:drift/drift.dart';

final class DemoDataSeeder {
  DemoDataSeeder(this.database);

  final AppDatabase database;

  static const schoolId = 'demo-school';
  static const schoolYearId = 'demo-school-year';
  static const groupId = 'demo-group';

  Future<void> ensureSeeded({bool reset = false, DateTime? now}) {
    return reset ? resetAndSeed(now: now) : seedIfEmpty(now: now);
  }

  Future<void> seedIfEmpty({DateTime? now}) async {
    _requireDemoProfile();
    final schools = await database.select(database.schools).get();
    if (schools.isNotEmpty) return;

    await database.transaction(() => _seedFixture(now ?? DateTime.now()));
  }

  Future<void> resetAndSeed({DateTime? now}) async {
    _requireDemoProfile();
    await database.transaction(() async {
      await _clearAll();
      await _seedFixture(now ?? DateTime.now());
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
    await database.delete(database.activityFormativeFields).go();
    await database.delete(database.activityGrades).go();
    await database.delete(database.activities).go();
    await database.delete(database.projectArticulatingAxes).go();
    await database.delete(database.projectFormativeFields).go();
    await database.delete(database.projectGrades).go();
    await database.delete(database.projects).go();
    await database.delete(database.attendanceEntries).go();
    await database.delete(database.attendanceDays).go();
    await database.delete(database.enrollments).go();
    await database.delete(database.students).go();
    await database.delete(database.groupGrades).go();
    await database.delete(database.teachingGroups).go();
    await database.delete(database.schoolContexts).go();
    await database.delete(database.schoolYears).go();
    await database.delete(database.schools).go();
  }

  Future<void> _seedFixture(DateTime now) async {
    final cycleStartYear = now.month >= 8 ? now.year : now.year - 1;
    final startsOn = DateTime(cycleStartYear, 8, 1);
    final endsOn = DateTime(cycleStartYear + 1, 7, 15);

    await database.into(database.schools).insert(
      const SchoolsCompanion(
        id: Value(schoolId),
        name: Value('Escuela Primaria Horizonte (DEMO)'),
        cct: Value('27DPR9999D'),
        organization: Value(SchoolOrganization.complete),
        state: Value('Tabasco'),
        municipality: Value('Centro'),
        locality: Value('Villahermosa'),
      ),
    );
    await database.into(database.schoolYears).insert(
      SchoolYearsCompanion(
        id: const Value(schoolYearId),
        label: Value('$cycleStartYear-${cycleStartYear + 1}'),
        startsOn: Value(startsOn),
        endsOn: Value(endsOn),
      ),
    );
    await database.into(database.schoolContexts).insert(
      const SchoolContextsCompanion(
        schoolId: Value(schoolId),
        schoolYearId: Value(schoolYearId),
      ),
    );
    await database.into(database.teachingGroups).insert(
      const TeachingGroupsCompanion(
        id: Value(groupId),
        schoolId: Value(schoolId),
        schoolYearId: Value(schoolYearId),
        name: Value('5° A · Grupo de demostración'),
        shift: Value('Matutino'),
        scheduleStartMinutes: Value(480),
        scheduleEndMinutes: Value(780),
      ),
    );
    await database.into(database.groupGrades).insert(
      const GroupGradesCompanion(
        groupId: Value(groupId),
        grade: Value(PrimaryGrade.fifth),
      ),
    );

    final students = _students(cycleStartYear);
    for (var index = 0; index < students.length; index++) {
      final student = students[index];
      await database.into(database.students).insert(
        StudentsCompanion(
          id: Value(student.id),
          givenNames: Value(student.givenNames),
          firstSurname: Value(student.firstSurname),
          secondSurname: Value(student.secondSurname),
          sex: Value(student.sex),
          birthDate: Value(student.birthDate),
        ),
      );
      await database.into(database.enrollments).insert(
        EnrollmentsCompanion(
          id: Value('demo-enrollment-${index + 1}'),
          studentId: Value(student.id),
          groupId: const Value(groupId),
          grade: const Value(PrimaryGrade.fifth),
          listNumber: Value(index + 1),
          startsOn: Value(startsOn),
        ),
      );
    }

    await _seedAttendance(students, startsOn, now);
    await _seedProjects(students, startsOn, now);
    await _seedStudentRecords(students, now);
  }

  Future<void> _seedAttendance(
    List<_DemoStudentSeed> students,
    DateTime startsOn,
    DateTime now,
  ) async {
    final days = _recentSchoolDays(now, startsOn, 10);
    for (var dayIndex = 0; dayIndex < days.length; dayIndex++) {
      final dayId = 'demo-attendance-${dayIndex + 1}';
      await database.into(database.attendanceDays).insert(
        AttendanceDaysCompanion(
          id: Value(dayId),
          groupId: const Value(groupId),
          date: Value(days[dayIndex]),
        ),
      );
      for (
        var studentIndex = 0;
        studentIndex < students.length;
        studentIndex++
      ) {
        final marker = (dayIndex * 3 + studentIndex) % 19;
        final status = switch (marker) {
          0 => AttendanceStatus.absent,
          4 => AttendanceStatus.late,
          9 => AttendanceStatus.justifiedAbsence,
          _ => AttendanceStatus.present,
        };
        await database.into(database.attendanceEntries).insert(
          AttendanceEntriesCompanion(
            attendanceDayId: Value(dayId),
            studentId: Value(students[studentIndex].id),
            status: Value(status),
          ),
        );
      }
    }
  }

  Future<void> _seedProjects(
    List<_DemoStudentSeed> students,
    DateTime startsOn,
    DateTime now,
  ) async {
    final projects = <_DemoProjectSeed>[
      const _DemoProjectSeed(
        id: 'demo-project-community',
        title: 'Nuestra comunidad, nuestras propuestas',
        lifecycle: ProjectLifecycle.inProgress,
        methodology: ProjectMethodology.communityProjects,
        axes: {
          ArticulatingAxis.inclusion,
          ArticulatingAxis.criticalThinking,
          ArticulatingAxis.culturesThroughReadingAndWriting,
        },
      ),
      const _DemoProjectSeed(
        id: 'demo-project-water',
        title: 'Guardianes del agua',
        lifecycle: ProjectLifecycle.completed,
        methodology: ProjectMethodology.inquirySteam,
        axes: {
          ArticulatingAxis.healthyLife,
          ArticulatingAxis.criticalThinking,
        },
      ),
      const _DemoProjectSeed(
        id: 'demo-project-reading',
        title: 'Historias que nos representan',
        lifecycle: ProjectLifecycle.draft,
        methodology: ProjectMethodology.serviceLearning,
        axes: {
          ArticulatingAxis.criticalInterculturality,
          ArticulatingAxis.artsAndAestheticExperiences,
        },
      ),
    ];

    for (final project in projects) {
      await database.into(database.projects).insert(
        ProjectsCompanion(
          id: Value(project.id),
          groupId: const Value(groupId),
          title: Value(project.title),
          lifecycle: Value(project.lifecycle),
          methodology: Value(project.methodology),
          formativeField: const Value(FormativeField.unspecified),
        ),
      );
      await database.into(database.projectGrades).insert(
        ProjectGradesCompanion(
          projectId: Value(project.id),
          grade: const Value(PrimaryGrade.fifth),
        ),
      );
      for (final axis in project.axes) {
        await database.into(database.projectArticulatingAxes).insert(
          ProjectArticulatingAxesCompanion(
            projectId: Value(project.id),
            articulatingAxis: Value(axis),
          ),
        );
      }
    }

    final activities = <_DemoActivitySeed>[
      _DemoActivitySeed(
        id: 'demo-activity-map',
        projectId: projects[0].id,
        identifier: 'COM-01',
        title: 'Mapa de necesidades de la comunidad',
        date: _notBefore(startsOn, now.subtract(const Duration(days: 14))),
        field: FormativeField.humanAndCommunity,
      ),
      _DemoActivitySeed(
        id: 'demo-activity-interview',
        projectId: projects[0].id,
        identifier: 'COM-02',
        title: 'Entrevista a una persona de la comunidad',
        date: _notBefore(startsOn, now.subtract(const Duration(days: 7))),
        field: FormativeField.languages,
      ),
      _DemoActivitySeed(
        id: 'demo-activity-water-log',
        projectId: projects[1].id,
        identifier: 'AGUA-01',
        title: 'Registro del consumo de agua',
        date: _notBefore(startsOn, now.subtract(const Duration(days: 10))),
        field: FormativeField.knowledgeAndScientificThought,
      ),
      _DemoActivitySeed(
        id: 'demo-activity-water-proposals',
        projectId: projects[1].id,
        identifier: 'AGUA-02',
        title: 'Propuestas para cuidar el agua',
        date: _notBefore(startsOn, now.subtract(const Duration(days: 3))),
        field: FormativeField.ethicsNatureAndSocieties,
      ),
    ];

    for (var activityIndex = 0;
        activityIndex < activities.length;
        activityIndex++) {
      final activity = activities[activityIndex];
      await database.into(database.activities).insert(
        ActivitiesCompanion(
          id: Value(activity.id),
          projectId: Value(activity.projectId),
          identifier: Value(activity.identifier),
          title: Value(activity.title),
          occursOn: Value(activity.date),
        ),
      );
      await database.into(database.activityFormativeFields).insert(
        ActivityFormativeFieldsCompanion(
          activityId: Value(activity.id),
          formativeField: Value(activity.field),
        ),
      );
      await database.into(database.activityGrades).insert(
        ActivityGradesCompanion(
          activityId: Value(activity.id),
          grade: const Value(PrimaryGrade.fifth),
        ),
      );

      for (
        var studentIndex = 0;
        studentIndex < students.length;
        studentIndex++
      ) {
        final student = students[studentIndex];
        await database.into(database.activityRoster).insert(
          ActivityRosterCompanion(
            activityId: Value(activity.id),
            studentId: Value(student.id),
            grade: const Value(PrimaryGrade.fifth),
          ),
        );

        final marker = activityIndex * students.length + studentIndex;
        if (marker % 6 == 0) continue;

        final isCarlaMap =
            activity.id == 'demo-activity-map' &&
            student.id == 'demo-student-carla';
        final notDelivered = isCarlaMap || marker % 11 == 0;
        await database.into(database.activityEvaluations).insert(
          ActivityEvaluationsCompanion(
            activityId: Value(activity.id),
            studentId: Value(student.id),
            deliveryStatus: Value(
              notDelivered
                  ? DeliveryStatus.notDelivered
                  : DeliveryStatus.delivered,
            ),
            achievement: Value(
              notDelivered
                  ? null
                  : AchievementLevel.values[
                        marker % AchievementLevel.values.length
                      ],
            ),
            observation: Value(
              notDelivered
                  ? 'Requiere acordar una nueva fecha de entrega.'
                  : marker % 4 == 0
                  ? 'Explica sus decisiones y mejora con la retroalimentación.'
                  : null,
            ),
          ),
        );
      }
    }
  }

  Future<void> _seedStudentRecords(
    List<_DemoStudentSeed> students,
    DateTime now,
  ) async {
    final records = <({String strengths, String difficulties, String supports})>[
      (
        strengths: 'Participa con iniciativa y comunica sus ideas con claridad.',
        difficulties: 'Necesita organizar mejor los pasos de tareas extensas.',
        supports: 'Usar listas breves de verificación y ejemplos resueltos.',
      ),
      (
        strengths: 'Relaciona datos y propone explicaciones fundamentadas.',
        difficulties: 'Le cuesta pedir ayuda cuando encuentra un obstáculo.',
        supports: 'Acordar pausas de revisión durante el trabajo independiente.',
      ),
      (
        strengths: 'Colabora y escucha otros puntos de vista.',
        difficulties: 'Requiere mayor seguridad al presentar frente al grupo.',
        supports: 'Preparar exposiciones cortas en pareja antes de plenaria.',
      ),
      (
        strengths: 'Lee con fluidez y recupera información relevante.',
        difficulties: 'Debe justificar con mayor detalle sus conclusiones.',
        supports: 'Usar preguntas guía: qué, cómo y por qué.',
      ),
    ];

    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final studentId = students[index].id;
      await database.into(database.studentRecords).insert(
        StudentRecordsCompanion(
          studentId: Value(studentId),
          strengths: Value(record.strengths),
          difficulties: Value(record.difficulties),
          supports: Value(record.supports),
        ),
      );
      await database.into(database.studentRecordEntries).insert(
        StudentRecordEntriesCompanion(
          id: Value('demo-record-observation-${index + 1}'),
          studentId: Value(studentId),
          kind: const Value(StudentRecordEntryKind.observation),
          occurredAt: Value(now.subtract(Duration(days: 8 - index))),
          content: const Value(
            'Observación ficticia: mostró avances durante el trabajo por proyecto.',
          ),
        ),
      );
      if (index < 2) {
        await database.into(database.studentRecordEntries).insert(
          StudentRecordEntriesCompanion(
            id: Value('demo-record-agreement-${index + 1}'),
            studentId: Value(studentId),
            kind: const Value(StudentRecordEntryKind.familyAgreement),
            occurredAt: Value(now.subtract(Duration(days: 5 - index))),
            content: const Value(
              'Acuerdo ficticio: revisar una actividad breve en casa dos veces por semana.',
            ),
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
      _DemoStudentSeed(
        'demo-student-ana',
        'Ana Sofía',
        'García',
        'López',
        StudentSex.female,
        DateTime(birthYear, 2, 14),
      ),
      _DemoStudentSeed(
        'demo-student-bruno',
        'Bruno',
        'Hernández',
        'Cruz',
        StudentSex.male,
        DateTime(birthYear, 5, 3),
      ),
      _DemoStudentSeed(
        'demo-student-carla',
        'Carla',
        'Pérez',
        'Sánchez',
        StudentSex.female,
        DateTime(birthYear, 8, 21),
      ),
      _DemoStudentSeed(
        'demo-student-04',
        'Emiliano',
        'Martínez',
        'Torres',
        StudentSex.male,
        DateTime(birthYear, 11, 9),
      ),
      _DemoStudentSeed(
        'demo-student-05',
        'Camila',
        'Jiménez',
        'Gómez',
        StudentSex.female,
        DateTime(birthYear, 1, 28),
      ),
      _DemoStudentSeed(
        'demo-student-06',
        'Santiago',
        'Morales',
        'Díaz',
        StudentSex.male,
        DateTime(birthYear, 4, 17),
      ),
      _DemoStudentSeed(
        'demo-student-07',
        'Ximena',
        'Ramírez',
        'Ortiz',
        StudentSex.female,
        DateTime(birthYear, 7, 6),
      ),
      _DemoStudentSeed(
        'demo-student-08',
        'Leonardo',
        'Castillo',
        'Reyes',
        StudentSex.male,
        DateTime(birthYear, 10, 24),
      ),
      _DemoStudentSeed(
        'demo-student-09',
        'Regina',
        'Vázquez',
        'Méndez',
        StudentSex.female,
        DateTime(birthYear, 3, 12),
      ),
      _DemoStudentSeed(
        'demo-student-10',
        'Diego',
        'Flores',
        'Aguilar',
        StudentSex.male,
        DateTime(birthYear, 6, 30),
      ),
      _DemoStudentSeed(
        'demo-student-11',
        'Renata',
        'Domínguez',
        'Ramos',
        StudentSex.female,
        DateTime(birthYear, 9, 15),
      ),
      _DemoStudentSeed(
        'demo-student-12',
        'Sebastián',
        'Navarro',
        'Ruiz',
        StudentSex.male,
        DateTime(birthYear, 12, 2),
      ),
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

final class _DemoProjectSeed {
  const _DemoProjectSeed({
    required this.id,
    required this.title,
    required this.lifecycle,
    required this.methodology,
    required this.axes,
  });

  final String id;
  final String title;
  final ProjectLifecycle lifecycle;
  final ProjectMethodology methodology;
  final Set<ArticulatingAxis> axes;
}

final class _DemoActivitySeed {
  const _DemoActivitySeed({
    required this.id,
    required this.projectId,
    required this.identifier,
    required this.title,
    required this.date,
    required this.field,
  });

  final String id;
  final String projectId;
  final String identifier;
  final String title;
  final DateTime date;
  final FormativeField field;
}
