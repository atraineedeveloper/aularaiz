import 'package:aularaiz/data/demo/demo_data_seeder.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final demoNow = DateTime(2026, 9, 15);

  test('demo reset seeds a rich deterministic cross-module fixture', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      storageProfile: StorageProfile.demo,
    );
    addTearDown(database.close);
    final seeder = DemoDataSeeder(database);

    await seeder.resetAndSeed(now: demoNow);

    expect(await database.select(database.schools).get(), hasLength(1));
    expect(await database.select(database.schoolYears).get(), hasLength(1));
    expect(await database.select(database.teachingGroups).get(), hasLength(1));
    expect(await database.select(database.students).get(), hasLength(12));
    expect(await database.select(database.enrollments).get(), hasLength(12));
    expect(await database.select(database.attendanceDays).get(), hasLength(10));
    expect(
      await database.select(database.attendanceEntries).get(),
      hasLength(120),
    );
    expect(await database.select(database.projects).get(), hasLength(3));
    expect(await database.select(database.activities).get(), hasLength(4));
    expect(await database.select(database.activityRoster).get(), hasLength(48));
    expect(
      await database.select(database.activityEvaluations).get(),
      hasLength(40),
    );
    expect(await database.select(database.studentRecords).get(), hasLength(4));
    expect(
      await database.select(database.studentRecordEntries).get(),
      hasLength(6),
    );

    final carlaEvaluation =
        await (database.select(database.activityEvaluations)..where(
              (table) =>
                  table.studentId.equals('demo-student-carla') &
                  table.activityId.equals('demo-activity-map'),
            ))
            .getSingle();
    expect(carlaEvaluation.deliveryStatus, DeliveryStatus.notDelivered);
    expect(carlaEvaluation.achievement, isNull);
  });

  test('demo reset is refused for a production-profile database', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      storageProfile: StorageProfile.production,
    );
    addTearDown(database.close);
    final seeder = DemoDataSeeder(database);

    await expectLater(
      seeder.resetAndSeed(now: demoNow),
      throwsA(isA<StateError>()),
    );
    expect(await database.select(database.schools).get(), isEmpty);
  });

  test('reset removes drift and restores deterministic ids', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      storageProfile: StorageProfile.demo,
    );
    addTearDown(database.close);
    final seeder = DemoDataSeeder(database);

    await seeder.resetAndSeed(now: demoNow);
    await database
        .into(database.students)
        .insert(
          const StudentsCompanion(
            id: Value('temporary-demo-student'),
            givenNames: Value('Temporal'),
            firstSurname: Value('Demo'),
          ),
        );

    await seeder.resetAndSeed(now: demoNow);

    final students = await database.select(database.students).get();
    expect(students, hasLength(12));
    expect(
      students.map((student) => student.id),
      containsAll(<String>[
        'demo-student-ana',
        'demo-student-bruno',
        'demo-student-carla',
        'demo-student-12',
      ]),
    );
    expect(
      students.map((student) => student.id),
      isNot(contains('temporary-demo-student')),
    );
  });

  test('seed if empty never overwrites an existing demo database', () async {
    final database = AppDatabase.forTesting(
      NativeDatabase.memory(),
      storageProfile: StorageProfile.demo,
    );
    addTearDown(database.close);
    final seeder = DemoDataSeeder(database);

    await seeder.seedIfEmpty(now: demoNow);
    await database
        .into(database.students)
        .insert(
          const StudentsCompanion(
            id: Value('teacher-added-demo-student'),
            givenNames: Value('Adicional'),
            firstSurname: Value('Demo'),
          ),
        );

    await seeder.seedIfEmpty(now: demoNow);

    expect(await database.select(database.students).get(), hasLength(13));
  });
}
