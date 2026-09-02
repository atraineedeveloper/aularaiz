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

  Future<void> seedIfEmpty({DateTime? now}) {
    return ensureSeeded(now: now);
  }

  Future<void> resetAndSeed({DateTime? now}) {
    return ensureSeeded(reset: true, now: now);
  }

  Future<void> ensureSeeded({bool reset = false, DateTime? now}) async {
    _requireDemoProfile();
    final effectiveNow = now ?? DateTime.now();

    if (reset) {
      await database.transaction(() async {
        await _clearAll();
        await _seedFixture(effectiveNow);
      });
      return;
    }

    final schools = await database.select(database.schools).get();
    if (schools.isNotEmpty) return;
    await database.transaction(() => _seedFixture(effectiveNow));
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
    await database.delete(database.teacherProfiles).go();
    await database.delete(database.schoolContexts).go();
    await database.delete(database.schoolYears).go();
    await database.delete(database.schools).go();
  }

  Future<void> _seedFixture(DateTime now) async {
    final cycleStartYear = now.month >= 8 ? now.year : now.year - 1;
    final startsOn = DateTime(cycleStartYear, 8, 1);
    final endsOn = DateTime(cycleStartYear + 1, 7, 15);

    await database
        .into(database.schools)
        .insert(
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
    await database
        .into(database.schoolYears)
        .insert(
          SchoolYearsCompanion(
            id: const Value(schoolYearId),
            label: Value('$cycleStartYear-${cycleStartYear + 1}'),
            startsOn: Value(startsOn),
            endsOn: Value(endsOn),
          ),
        );
    await database
        .into(database.schoolContexts)
        .insert(
          const SchoolContextsCompanion(
            schoolId: Value(schoolId),
            schoolYearId: Value(schoolYearId),
          ),
        );
    await database
        .into(database.teachingGroups)
        .insert(
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
    await database
        .into(database.groupGrades)
        .insert(
          const GroupGradesCompanion(
            groupId: Value(groupId),
            grade: Value(PrimaryGrade.fifth),
          ),
        );

    final students = _students(cycleStartYear);
    for (var index = 0; index < students.length; index++) {
      final student = students[index];
      await database
          .into(database.students)
          .insert(
            StudentsCompanion(
              id: Value(student.id),
              givenNames: Value(student.givenNames),
              firstSurname: Value(student.firstSurname),
              secondSurname: Value(student.secondSurname),
              sex: Value(student.sex),
              birthDate: Value(student.birthDate),
            ),
          );
      await database
          .into(database.enrollments)
          .insert(
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
      await database
          .into(database.attendanceDays)
          .insert(
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
        await database
            .into(database.attendanceEntries)
            .insert(
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
    const projects = <_DemoProjectSeed>[
      _DemoProjectSeed(
        id: 'demo-project-community',
        title: 'Nuestra comunidad, nuestras propuestas',
        lifecycle: ProjectLifecycle.inProgress,
        methodology: ProjectMethodology.communityProjects,
        field: FormativeField.humanAndCommunity,
        axes: {
          ArticulatingAxis.inclusion,
          ArticulatingAxis.criticalThinking,
          ArticulatingAxis.culturesThroughReadingAndWriting,
        },
      ),
      _DemoProjectSeed(
        id: 'demo-project-water',
        title: 'Guardianes del agua',
        lifecycle: ProjectLifecycle.completed,
        methodology: ProjectMethodology.inquirySteam,
        field: FormativeField.knowledgeAndScientificThought,
        axes: {ArticulatingAxis.healthyLife, ArticulatingAxis.criticalThinking},
      ),
      _DemoProjectSeed(
        id: 'demo-project-reading',
        title: 'Historias que nos representan',
        lifecycle: ProjectLifecycle.draft,
        methodology: ProjectMethodology.serviceLearning,
        field: FormativeField.languages,
        axes: {
          ArticulatingAxis.criticalInterculturality,
          ArticulatingAxis.artsAndAestheticExperiences,
        },
      ),
    ];

    for (final project in projects) {
      await database
          .into(database.projects)
          .insert(
            ProjectsCompanion(
              id: Value(project.id),
              groupId: const Value(groupId),
              title: Value(project.title),
              lifecycle: Value(project.lifecycle),
              methodology: Value(project.methodology),
              formativeField: Value(project.field),
            ),
          );
      await database
          .into(database.projectGrades)
          .insert(
            ProjectGradesCompanion(
              projectId: Value(project.id),
              grade: const Value(PrimaryGrade.fifth),
            ),
          );
      await database
          .into(database.projectFormativeFields)
          .insert(
            ProjectFormativeFieldsCompanion(
              projectId: Value(project.id),
              formativeField: Value(project.field),
            ),
          );
      for (final axis in project.axes) {
        await database
            .into(database.projectArticulatingAxes)
            .insert(
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
        projectId: 'demo-project-community',
        identifier: 'COM-01',
        title: 'Mapa de necesidades de la comunidad',
        date: _notBefore(startsOn, now.subtract(const Duration(days: 14))),
        field: FormativeField.humanAndCommunity,
      ),
      _DemoActivitySeed(
        id: 'demo-activity-interview',
        projectId: 'demo-project-community',
        identifier: 'COM-02',
        title: 'Entrevista a una persona de la comunidad',
        date: _notBefore(startsOn, now.subtract(const Duration(days: 7))),
        field: FormativeField.languages,
      ),
      _DemoActivitySeed(
        id: 'demo-activity-water-log',
        projectId: 'demo-project-water',
        identifier: 'AGUA-01',
        title: 'Registro del consumo de agua',
        date: _notBefore(startsOn, now.subtract(const Duration(days: 10))),
        field: FormativeField.knowledgeAndScientificThought,
      ),
      _DemoActivitySeed(
        id: 'demo-activity-water-proposals',
        projectId: 'demo-project-water',
        identifier: 'AGUA-02',
        title: 'Propuestas para cuidar el agua',
        date: _notBefore(startsOn, now.subtract(const Duration(days: 3))),
        field: FormativeField.ethicsNatureAndSocieties,
      ),
    ];

    for (
      var activityIndex = 0;
      activityIndex < activities.length;
      activityIndex++
    ) {
      final activity = activities[activityIndex];
      await database
          .into(database.activities)
          .insert(
            ActivitiesCompanion(
              id: Value(activity.id),
              projectId: Value(activity.projectId),
              identifier: Value(activity.identifier),
              title: Value(activity.title),
              occursOn: Value(activity.date),
            ),
          );
      await database
          .into(database.activityFormativeFields)
          .insert(
            ActivityFormativeFieldsCompanion(
              activityId: Value(activity.id),
              formativeField: Value(activity.field),
            ),
          );
      await database
          .into(database.activityGrades)
          .insert(
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
        await database
            .into(database.activityRoster)
            .insert(
              ActivityRosterCompanion(
                activityId: Value(activity.id),
                studentId: Value(student.id),
                grade: const Value(PrimaryGrade.fifth),
              ),
            );

        final marker = activityIndex * students.length + studentIndex;
        if (marker % 6 == 0) continue;
        final carlaMap =
            activity.id == 'demo-activity-map' &&
            student.id == 'demo-student-carla';
        final notDelivered = carlaMap || marker % 11 == 0;
        await database
            .into(database.activityEvaluations)
            .insert(
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
                      : AchievementLevel.values[marker %
                            AchievementLevel.values.length],
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
    const records = <_DemoRecordSeed>[
      _DemoRecordSeed(
        strengths:
            'Participa con iniciativa y comunica sus ideas con claridad.',
        difficulties: 'Necesita organizar mejor los pasos de tareas extensas.',
        supports: 'Usar listas breves de verificación y ejemplos resueltos.',
      ),
      _DemoRecordSeed(
        strengths: 'Relaciona datos y propone explicaciones fundamentadas.',
        difficulties: 'Le cuesta pedir ayuda cuando encuentra un obstáculo.',
        supports:
            'Acordar pausas de revisión durante el trabajo independiente.',
      ),
      _DemoRecordSeed(
        strengths: 'Colabora y escucha otros puntos de vista.',
        difficulties: 'Requiere mayor seguridad al presentar frente al grupo.',
        supports: 'Preparar exposiciones cortas en pareja antes de plenaria.',
      ),
      _DemoRecordSeed(
        strengths: 'Lee con fluidez y recupera información relevante.',
        difficulties: 'Debe justificar con mayor detalle sus conclusiones.',
        supports: 'Usar preguntas guía: qué, cómo y por qué.',
      ),
    ];

    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final studentId = students[index].id;
      await database
          .into(database.studentRecords)
          .insert(
            StudentRecordsCompanion(
              studentId: Value(studentId),
              strengths: Value(record.strengths),
              difficulties: Value(record.difficulties),
              supports: Value(record.supports),
            ),
          );
      await database
          .into(database.studentRecordEntries)
          .insert(
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
        await database
            .into(database.studentRecordEntries)
            .insert(
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
      if (cursor.weekday >= DateTime.monday &&
          cursor.weekday <= DateTime.friday) {
        result.add(cursor);
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return result.reversed.toList(growable: false);
  }

  DateTime _notBefore(DateTime floor, DateTime candidate) {
    return candidate.isBefore(floor) ? floor : candidate;
  }

  List<_DemoStudentSeed> _students(int cycleStartYear) {
    return <_DemoStudentSeed>[
      _DemoStudentSeed(
        id: 'demo-student-ana',
        givenNames: 'Ana Sofía',
        firstSurname: 'Solís',
        secondSurname: 'Pérez',
        sex: StudentSex.female,
        birthDate: DateTime(cycleStartYear - 10, 2, 10),
      ),
      _DemoStudentSeed(
        id: 'demo-student-bruno',
        givenNames: 'Bruno',
        firstSurname: 'Méndez',
        secondSurname: 'López',
        sex: StudentSex.male,
        birthDate: DateTime(cycleStartYear - 10, 11, 22),
      ),
      _DemoStudentSeed(
        id: 'demo-student-carla',
        givenNames: 'Carla',
        firstSurname: 'Ruiz',
        secondSurname: 'García',
        sex: StudentSex.female,
        birthDate: DateTime(cycleStartYear - 10, 6, 15),
      ),
      _DemoStudentSeed(
        id: 'demo-student-04',
        givenNames: 'Diego',
        firstSurname: 'Hernández',
        secondSurname: 'Cruz',
        sex: StudentSex.male,
        birthDate: DateTime(cycleStartYear - 10, 4, 3),
      ),
      _DemoStudentSeed(
        id: 'demo-student-05',
        givenNames: 'Elena',
        firstSurname: 'Torres',
        secondSurname: 'Jiménez',
        sex: StudentSex.female,
        birthDate: DateTime(cycleStartYear - 10, 8, 29),
      ),
      _DemoStudentSeed(
        id: 'demo-student-06',
        givenNames: 'Fernando',
        firstSurname: 'Sánchez',
        secondSurname: 'Díaz',
        sex: StudentSex.male,
        birthDate: DateTime(cycleStartYear - 10, 1, 19),
      ),
      _DemoStudentSeed(
        id: 'demo-student-07',
        givenNames: 'Gabriela',
        firstSurname: 'Morales',
        secondSurname: 'Vega',
        sex: StudentSex.female,
        birthDate: DateTime(cycleStartYear - 10, 3, 12),
      ),
      _DemoStudentSeed(
        id: 'demo-student-08',
        givenNames: 'Hugo',
        firstSurname: 'Castillo',
        secondSurname: 'Ramos',
        sex: StudentSex.male,
        birthDate: DateTime(cycleStartYear - 10, 9, 7),
      ),
      _DemoStudentSeed(
        id: 'demo-student-09',
        givenNames: 'Ivanna',
        firstSurname: 'Ortega',
        secondSurname: 'Flores',
        sex: StudentSex.female,
        birthDate: DateTime(cycleStartYear - 10, 12, 5),
      ),
      _DemoStudentSeed(
        id: 'demo-student-10',
        givenNames: 'Jorge',
        firstSurname: 'Navarro',
        secondSurname: 'Reyes',
        sex: StudentSex.male,
        birthDate: DateTime(cycleStartYear - 10, 5, 21),
      ),
      _DemoStudentSeed(
        id: 'demo-student-11',
        givenNames: 'Karla',
        firstSurname: 'Domínguez',
        secondSurname: 'Santos',
        sex: StudentSex.female,
        birthDate: DateTime(cycleStartYear - 10, 7, 18),
      ),
      _DemoStudentSeed(
        id: 'demo-student-12',
        givenNames: 'Luis',
        firstSurname: 'Aguilar',
        secondSurname: 'Romero',
        sex: StudentSex.male,
        birthDate: DateTime(cycleStartYear - 10, 10, 9),
      ),
    ];
  }
}

final class _DemoStudentSeed {
  const _DemoStudentSeed({
    required this.id,
    required this.givenNames,
    required this.firstSurname,
    required this.secondSurname,
    required this.sex,
    required this.birthDate,
  });

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
    required this.field,
    required this.axes,
  });

  final String id;
  final String title;
  final ProjectLifecycle lifecycle;
  final ProjectMethodology methodology;
  final FormativeField field;
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

final class _DemoRecordSeed {
  const _DemoRecordSeed({
    required this.strengths,
    required this.difficulties,
    required this.supports,
  });

  final String strengths;
  final String difficulties;
  final String supports;
}
