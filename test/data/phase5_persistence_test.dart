import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_evaluation_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_record_repository.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftEvaluationRepository evaluationRepository;
  late DriftStudentRecordRepository recordRepository;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    evaluationRepository = DriftEvaluationRepository(database);
    recordRepository = DriftStudentRecordRepository(database);

    await database.customSelect('SELECT 1').get();
    await database.customStatement('PRAGMA foreign_keys = OFF');
    await database
        .into(database.students)
        .insert(
          const StudentsCompanion(
            id: Value('student-1'),
            givenNames: Value('Alumno'),
            firstSurname: Value('Prueba'),
          ),
        );
    await database
        .into(database.activities)
        .insert(
          const ActivitiesCompanion(
            id: Value('activity-1'),
            projectId: Value('project-fixture'),
            title: Value('Actividad de prueba'),
          ),
        );
    await database
        .into(database.activityGrades)
        .insert(
          const ActivityGradesCompanion(
            activityId: Value('activity-1'),
            grade: Value(PrimaryGrade.first),
          ),
        );
    await database
        .into(database.activityRoster)
        .insert(
          const ActivityRosterCompanion(
            activityId: Value('activity-1'),
            studentId: Value('student-1'),
            grade: Value(PrimaryGrade.first),
          ),
        );
    await database.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async {
    await database.close();
  });

  test('formative evaluation round-trips through SQLite', () async {
    final evaluation = ActivityEvaluation(
      activityId: 'activity-1',
      studentId: 'student-1',
      deliveryStatus: DeliveryStatus.delivered,
      achievement: AchievementLevel.inProgress,
      observation: 'Explica el procedimiento con apoyo.',
    );

    await evaluationRepository.save(evaluation);

    final restored = await evaluationRepository.find(
      activityId: 'activity-1',
      studentId: 'student-1',
    );
    expect(restored?.deliveryStatus, DeliveryStatus.delivered);
    expect(restored?.achievement, AchievementLevel.inProgress);
    expect(restored?.observation, 'Explica el procedimiento con apoyo.');
  });

  test('student profile and chronological entries round-trip through SQLite', () async {
    await recordRepository.save(
      StudentRecord(
        studentId: 'student-1',
        strengths: 'Participa y comunica sus ideas.',
        difficulties: 'Requiere más tiempo en problemas de varios pasos.',
        supports: 'Apoyos visuales y modelado inicial.',
      ),
    );
    await recordRepository.addEntry(
      StudentRecordEntry(
        id: 'entry-1',
        studentId: 'student-1',
        kind: StudentRecordEntryKind.observation,
        occurredAt: DateTime.utc(2026, 9, 10, 14),
        text: 'Resolvió una tarea con menor nivel de andamiaje.',
      ),
    );
    await recordRepository.addEntry(
      StudentRecordEntry(
        id: 'entry-2',
        studentId: 'student-1',
        kind: StudentRecordEntryKind.familyAgreement,
        occurredAt: DateTime.utc(2026, 9, 11, 14),
        text: 'Se acordó reforzar lectura breve en casa.',
      ),
    );

    final restored = await recordRepository.load('student-1');
    final entries = await recordRepository.listEntries('student-1');

    expect(restored?.strengths, 'Participa y comunica sus ideas.');
    expect(restored?.supports, 'Apoyos visuales y modelado inicial.');
    expect(entries, hasLength(2));
    expect(entries.first.kind, StudentRecordEntryKind.familyAgreement);
    expect(entries.last.kind, StudentRecordEntryKind.observation);
  });
}
