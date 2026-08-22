import 'package:aularaiz/data/local/schema/teaching_groups.dart';
import 'package:drift/drift.dart';

class GroupGrades extends Table {
  late final groupId = text().references(
    TeachingGroups,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final grade = integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{groupId, grade};
}
