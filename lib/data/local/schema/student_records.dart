import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:drift/drift.dart';

@DataClassName('StudentRecordRow')
class StudentRecords extends Table with SyncMetadataColumns {
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final strengths = text().nullable()();
  late final difficulties = text().nullable()();
  late final supports = text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{studentId};
}
