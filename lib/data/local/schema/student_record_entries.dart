import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:drift/drift.dart';

@DataClassName('StudentRecordEntryRow')
class StudentRecordEntries extends Table {
  late final id = text()();
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final kind = textEnum<StudentRecordEntryKind>()();
  late final occurredAt = dateTime()();
  late final content = text().named('text')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
