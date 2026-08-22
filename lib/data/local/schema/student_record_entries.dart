import 'package:aularaiz/data/local/schema/students.dart';
import 'package:drift/drift.dart';

class StudentRecordEntries extends Table {
  late final id = text()();
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final kind = integer()();
  late final occurredAt = dateTime()();
  late final text = text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
