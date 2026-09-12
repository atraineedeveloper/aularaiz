import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';
import 'package:drift/drift.dart';

@DataClassName('LiteracyAssessmentRow')
class LiteracyAssessments extends Table {
  late final id = text()();
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final assessedAt = dateTime()();
  late final writingLevel = textEnum<WritingLevel>()();
  late final readingLevel = textEnum<ReadingLevel>()();
  late final notes = text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
