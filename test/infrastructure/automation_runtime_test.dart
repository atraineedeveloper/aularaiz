import 'dart:io';

import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/data/repositories/drift_student_record_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_repository.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:aularaiz/infrastructure/automation/automation_runtime.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'aularaiz-agent-test-',
    );
    databaseFile = File(
      '${temporaryDirectory.path}${Platform.pathSeparator}aularaiz-production.sqlite',
    );

    final database = AppDatabase.forTesting(
      NativeDatabase(databaseFile),
      storageProfile: StorageProfile.production,
    );
    try {
      await DriftStudentRepository(database).save(
        Student(id: 'student-1', givenNames: 'Ana', firstSurname: 'Pérez'),
      );
    } finally {
      await database.close();
    }
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('explicit database path is discoverable', () async {
    final located = await AutomationDatabaseLocator.findExisting(
      profile: StorageProfile.production,
      explicitPath: databaseFile.path,
    );

    expect(located?.absolute.path, databaseFile.absolute.path);
  });

  test(
    'dry-run does not write and explicit apply persists through use case',
    () async {
      final runtime = await AutomationRuntime.open(
        databaseFile: databaseFile,
        profile: StorageProfile.production,
      );
      try {
        final preview = await runtime.service.studentNote(
          studentId: 'student-1',
          kind: StudentRecordEntryKind.observation,
          occurredAt: DateTime(2026, 9, 5),
          text: 'Revisar avance lector',
        );
        expect(preview.data['dry_run'], isTrue);

        final applied = await runtime.service.studentNote(
          studentId: 'student-1',
          kind: StudentRecordEntryKind.observation,
          occurredAt: DateTime(2026, 9, 5),
          text: 'Revisar avance lector',
          apply: true,
          privacy: const AutomationPrivacy(includePersonalData: true),
        );
        expect(applied.data['applied'], isTrue);
      } finally {
        await runtime.close();
      }

      final verificationDatabase = AppDatabase.forTesting(
        NativeDatabase(databaseFile),
        storageProfile: StorageProfile.production,
      );
      try {
        final entries = await DriftStudentRecordRepository(verificationDatabase)
            .listEntries('student-1');
        expect(entries, hasLength(1));
        expect(entries.single.text, 'Revisar avance lector');
        expect(entries.single.kind, StudentRecordEntryKind.observation);
      } finally {
        await verificationDatabase.close();
      }
    },
  );
}
