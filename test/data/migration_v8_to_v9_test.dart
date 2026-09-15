import 'dart:io';

import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_literacy_assessment_repository.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aularaiz-migration-');
    file = File('${directory.path}${Platform.pathSeparator}db.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test(
    'migrates a populated v8 database to v9 with literacy assessments',
    () async {
      final initial = AppDatabase.forTesting(NativeDatabase(file));
      await initial.customSelect('SELECT 1').getSingle();
      await initial
          .into(initial.students)
          .insert(
            const StudentsCompanion(
              id: Value('student-1'),
              givenNames: Value('Ana'),
              firstSurname: Value('Lopez'),
            ),
          );
      await initial.close();

      _downgradeToV8Shape(file.path);

      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);
      await upgraded.customSelect('SELECT 1').getSingle();

      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(
        version.read<int>('user_version'),
        AppDatabase.currentSchemaVersion,
      );
      expect(await _count(upgraded, 'SELECT COUNT(*) AS n FROM students'), 1);
      expect(await _tableExists(upgraded, 'literacy_assessments'), isTrue);

      final repository = DriftLiteracyAssessmentRepository(upgraded);
      await repository.save(
        LiteracyAssessment(
          id: 'literacy-1',
          studentId: 'student-1',
          assessedAt: DateTime(2026, 9, 12),
          writingLevel: WritingLevel.syllabic,
          readingLevel: ReadingLevel.wordByWord,
          notes: 'Capturado despues de evaluar en papel.',
        ),
      );
      expect(
        (await repository.latestForStudent('student-1'))?.id,
        'literacy-1',
      );

      await expectLater(
        upgraded
            .into(upgraded.literacyAssessments)
            .insert(
              LiteracyAssessmentsCompanion(
                id: const Value('orphan-literacy'),
                studentId: const Value('missing-student'),
                assessedAt: Value(DateTime(2026, 9, 12)),
                writingLevel: const Value(WritingLevel.syllabic),
                readingLevel: const Value(ReadingLevel.syllabic),
              ),
            ),
        throwsA(isA<Exception>()),
      );
    },
  );
}

void _downgradeToV8Shape(String path) {
  final raw = sqlite3.open(path);
  try {
    raw.execute('DROP TABLE literacy_assessments');
    raw.execute('PRAGMA user_version = 8');
  } finally {
    raw.close();
  }
}

Future<bool> _tableExists(AppDatabase database, String tableName) async {
  final rows = await database
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(tableName)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<int> _count(AppDatabase database, String sql) async {
  final row = await database.customSelect(sql).getSingle();
  return row.read<int>('n');
}
