import 'dart:io';

import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/sync/record_level_sync_service.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late AppDatabase local;
  late File incomingFile;
  late AppDatabase incoming;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aularaiz-sync-');
    local = AppDatabase.forTesting(NativeDatabase.memory());
    incomingFile = File(
      '${directory.path}${Platform.pathSeparator}incoming.sqlite',
    );
    incoming = AppDatabase.forTesting(NativeDatabase(incomingFile));
  });

  tearDown(() async {
    await incoming.close();
    await local.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'merges missing and newer records without overwriting newer local rows',
    () async {
      await local
          .into(local.students)
          .insert(
            StudentsCompanion.insert(
              id: 'student-updated',
              givenNames: 'Nombre viejo',
              firstSurname: 'Local',
              updatedAt: Value(_stamp(1)),
            ),
          );
      await local
          .into(local.students)
          .insert(
            StudentsCompanion.insert(
              id: 'student-kept',
              givenNames: 'Nombre local',
              firstSurname: 'Reciente',
              updatedAt: Value(_stamp(5)),
            ),
          );
      await local
          .into(local.students)
          .insert(
            StudentsCompanion.insert(
              id: 'student-deleted',
              givenNames: 'Será',
              firstSurname: 'Borrado',
              updatedAt: Value(_stamp(3)),
            ),
          );

      await incoming
          .into(incoming.students)
          .insert(
            StudentsCompanion.insert(
              id: 'student-updated',
              givenNames: 'Nombre nuevo',
              firstSurname: 'Entrante',
              updatedAt: Value(_stamp(10)),
            ),
          );
      await incoming
          .into(incoming.students)
          .insert(
            StudentsCompanion.insert(
              id: 'student-deleted',
              givenNames: 'Será',
              firstSurname: 'Borrado',
              updatedAt: Value(_stamp(12)),
              deletedAt: Value(_stamp(12)),
            ),
          );
      await incoming
          .into(incoming.students)
          .insert(
            StudentsCompanion.insert(
              id: 'student-kept',
              givenNames: 'Nombre entrante viejo',
              firstSurname: 'No gana',
              updatedAt: Value(_stamp(2)),
            ),
          );
      await incoming
          .into(incoming.students)
          .insert(
            StudentsCompanion.insert(
              id: 'student-inserted',
              givenNames: 'Alumno nuevo',
              firstSurname: 'Entrante',
              createdAt: Value(_stamp(10)),
              updatedAt: Value(_stamp(10)),
            ),
          );

      await incoming.close();

      final summary = await RecordLevelSyncService(
        database: local,
        profile: StorageProfile.production,
        currentSchemaVersion: AppDatabase.currentSchemaVersion,
      ).mergeDatabaseFile(incomingFile);

      expect(summary.inserted, 1);
      expect(summary.updated, 2);
      expect(summary.skipped, greaterThanOrEqualTo(1));

      final updated = await (local.select(
        local.students,
      )..where((table) => table.id.equals('student-updated'))).getSingle();
      final kept = await (local.select(
        local.students,
      )..where((table) => table.id.equals('student-kept'))).getSingle();
      final inserted = await (local.select(
        local.students,
      )..where((table) => table.id.equals('student-inserted'))).getSingle();
      final deleted = await (local.select(
        local.students,
      )..where((table) => table.id.equals('student-deleted'))).getSingle();

      expect(updated.givenNames, 'Nombre nuevo');
      expect(updated.firstSurname, 'Entrante');
      expect(kept.givenNames, 'Nombre local');
      expect(kept.firstSurname, 'Reciente');
      expect(inserted.givenNames, 'Alumno nuevo');
      expect(deleted.deletedAt, isNotNull);
    },
  );
}

DateTime _stamp(int minutes) =>
    DateTime.fromMillisecondsSinceEpoch(minutes * 60000, isUtc: true);
