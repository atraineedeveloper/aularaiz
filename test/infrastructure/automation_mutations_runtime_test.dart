import 'dart:io';

import 'package:aularaiz/data/demo/demo_data_seeder.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/data/repositories/drift_attendance_repository.dart';
import 'package:aularaiz/data/repositories/drift_enrollment_repository.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
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

  test('attendance mutation is dry-run by default and persists on apply', () async {
    final runtime = await AutomationRuntime.open(
      databaseFile: databaseFile,
      profile: StorageProfile.demo,
    );
    try {
      final date = DateTime(2026, 9, 21);
      final attendanceRepository = DriftAttendanceRepository(runtime.database);

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
  });

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
      enrollments.sort((left, right) => left.startsOn.compareTo(right.startsOn));
      expect(enrollments.last.startsOn, DateTime(2026, 10, 1));
      expect(enrollments.last.endsOn, isNull);
    } finally {
      await runtime.close();
    }
  });
}
