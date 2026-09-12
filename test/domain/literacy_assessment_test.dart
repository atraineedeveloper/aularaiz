import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates a valid literacy assessment with normalized notes', () {
    final assessment = LiteracyAssessment(
      id: 'literacy-1',
      studentId: 'student-1',
      assessedAt: DateTime(2026, 9, 12, 10),
      writingLevel: WritingLevel.syllabicAlphabetic,
      readingLevel: ReadingLevel.wordByWord,
      notes: '  Lee palabra por palabra.  ',
    );

    expect(assessment.assessedAt.isUtc, isTrue);
    expect(assessment.notes, 'Lee palabra por palabra.');
    expect(assessment.writingLevel, WritingLevel.syllabicAlphabetic);
    expect(assessment.readingLevel, ReadingLevel.wordByWord);
  });

  test('normalizes blank notes to null', () {
    final assessment = LiteracyAssessment(
      id: 'literacy-1',
      studentId: 'student-1',
      assessedAt: DateTime(2026, 9, 12),
      writingLevel: WritingLevel.presyllabic,
      readingLevel: ReadingLevel.doesNotRead,
      notes: '   ',
    );

    expect(assessment.notes, isNull);
  });

  test('rejects empty identifiers', () {
    expect(
      () => LiteracyAssessment(
        id: ' ',
        studentId: 'student-1',
        assessedAt: DateTime(2026, 9, 12),
        writingLevel: WritingLevel.syllabic,
        readingLevel: ReadingLevel.syllabic,
      ),
      throwsArgumentError,
    );
    expect(
      () => LiteracyAssessment(
        id: 'literacy-1',
        studentId: ' ',
        assessedAt: DateTime(2026, 9, 12),
        writingLevel: WritingLevel.syllabic,
        readingLevel: ReadingLevel.syllabic,
      ),
      throwsArgumentError,
    );
  });

  test('keeps writing and reading enums independent', () {
    expect(WritingLevel.values, <WritingLevel>[
      WritingLevel.presyllabic,
      WritingLevel.syllabic,
      WritingLevel.syllabicAlphabetic,
      WritingLevel.alphabetic,
    ]);
    expect(ReadingLevel.values, <ReadingLevel>[
      ReadingLevel.doesNotRead,
      ReadingLevel.syllabic,
      ReadingLevel.wordByWord,
      ReadingLevel.sentence,
      ReadingLevel.fluent,
    ]);
  });
}
