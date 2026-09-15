import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:aularaiz/data/local/schema/teaching_groups.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:drift/drift.dart';

class GroupGrades extends Table with SyncMetadataColumns {
  late final groupId = text().references(
    TeachingGroups,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final grade = textEnum<PrimaryGrade>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{groupId, grade};
}
