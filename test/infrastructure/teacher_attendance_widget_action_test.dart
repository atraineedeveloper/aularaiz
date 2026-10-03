import 'dart:io';

import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_teacher_attendance_repository.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/infrastructure/widgets/teacher_attendance_widget_action.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late TeacherAttendanceWidgetAction writer;
  final arrival = DateTime(2026, 10, 3, 8, 10);
  late bool previousMultipleDatabaseWarning;

  setUpAll(() {
    previousMultipleDatabaseWarning =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases =
        previousMultipleDatabaseWarning;
  });

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    writer = TeacherAttendanceWidgetAction(
      database,
      deviceIdProvider: () async => 'widget-device',
    );
    await _seed(database);
  });
  tearDown(() => database.close());

  test('arrival persists schedule and sync metadata; repeated tap does not change it', () async {
    expect(
      await writer.apply(
        schoolId: 'school',
        action: 'arrival',
        expectedDate: '2026-10-03',
        at: arrival,
      ),
      TeacherWidgetActionResult.saved,
    );
    expect(
      await writer.apply(
        schoolId: 'school',
        action: 'arrival',
        expectedDate: '2026-10-03',
        at: arrival.add(const Duration(minutes: 2)),
      ),
      TeacherWidgetActionResult.unchanged,
    );

    final rows = await database.select(database.teacherAttendanceRecords).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.arrivedAt.toUtc(), arrival.toUtc());
    expect(row.departedAt, isNull);
    expect(row.expectedArrivalMinute, 480);
    expect(row.expectedDepartureMinute, 900);
    expect(row.arrivalGraceMinutes, 10);
    expect(row.updatedByDeviceId, 'widget-device');
    expect(row.createdAt, isNotNull);
    expect(row.updatedAt, isNotNull);
  });

  test('departure requires an open workday and never overwrites an existing departure', () async {
    final departure = DateTime(2026, 10, 3, 15);
    expect(
      await writer.apply(
        schoolId: 'school',
        action: 'departure',
        expectedDate: '2026-10-03',
        at: departure,
      ),
      TeacherWidgetActionResult.unchanged,
    );
    expect(
      await database.select(database.teacherAttendanceRecords).get(),
      isEmpty,
    );
    await writer.apply(
      schoolId: 'school',
      action: 'arrival',
      expectedDate: '2026-10-03',
      at: arrival,
    );
    expect(
      await writer.apply(
        schoolId: 'school',
        action: 'departure',
        expectedDate: '2026-10-03',
        at: departure,
      ),
      TeacherWidgetActionResult.saved,
    );
    expect(
      await writer.apply(
        schoolId: 'school',
        action: 'departure',
        expectedDate: '2026-10-03',
        at: departure.add(const Duration(minutes: 3)),
      ),
      TeacherWidgetActionResult.unchanged,
    );
    final record = await DriftTeacherAttendanceRepository(database)
        .findForDate('school', departure);
    expect(record!.arrivedAt.toUtc(), arrival.toUtc());
    expect(record.departedAt!.toUtc(), departure.toUtc());
  });

  test(
    'a stale date, missing school or invalid action cannot create a record',
    () async {
      expect(
        await writer.apply(
          schoolId: 'school',
          action: 'arrival',
          expectedDate: '2026-10-02',
          at: arrival,
        ),
        TeacherWidgetActionResult.stale,
      );
      expect(
        await writer.apply(
          schoolId: 'missing',
          action: 'arrival',
          expectedDate: '2026-10-03',
          at: arrival,
        ),
        TeacherWidgetActionResult.unavailable,
      );
      expect(
        await writer.apply(
          schoolId: 'school',
          action: 'open',
          expectedDate: '2026-10-03',
          at: arrival,
        ),
        TeacherWidgetActionResult.unavailable,
      );
      expect(
        await database.select(database.teacherAttendanceRecords).get(),
        isEmpty,
      );
    },
  );

  test(
    'separate SQLite connections serialize simultaneous arrival taps',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'aularaiz-widget-action-',
      );
      final file = File(
        '${directory.path}${Platform.pathSeparator}widget.sqlite',
      );
      final first = AppDatabase.forTesting(
        NativeDatabase.createInBackground(file),
      );
      final second = AppDatabase.forTesting(
        NativeDatabase.createInBackground(file),
      );
      try {
        await _seed(first);
        await second.customSelect('SELECT 1').get();
        await first.customStatement('PRAGMA busy_timeout = 5000');
        await second.customStatement('PRAGMA busy_timeout = 5000');
        final results = await Future.wait([
          TeacherAttendanceWidgetAction(first).apply(
            schoolId: 'school',
            action: 'arrival',
            expectedDate: '2026-10-03',
            at: arrival,
          ),
          TeacherAttendanceWidgetAction(second).apply(
            schoolId: 'school',
            action: 'arrival',
            expectedDate: '2026-10-03',
            at: arrival,
          ),
        ]);
        expect(
          results.where((value) => value == TeacherWidgetActionResult.saved),
          hasLength(1),
        );
        expect(
          results.where(
            (value) => value == TeacherWidgetActionResult.unchanged,
          ),
          hasLength(1),
        );
        final records = await first
            .select(first.teacherAttendanceRecords)
            .get();
        expect(records, hasLength(1));
        expect(records.single.departedAt, isNull);
      } finally {
        await second.close();
        await first.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

Future<void> _seed(AppDatabase database) async {
  await database
      .into(database.schools)
      .insert(
        SchoolsCompanion.insert(
          id: 'school',
          name: 'Benito Juárez',
          organization: SchoolOrganization.unitary,
        ),
      );
  await database
      .into(database.teacherAttendanceSchedules)
      .insert(
        TeacherAttendanceSchedulesCompanion.insert(
          schoolId: 'school',
          expectedArrivalMinute: const Value(480),
          expectedDepartureMinute: const Value(900),
          arrivalGraceMinutes: const Value(10),
        ),
      );
}
