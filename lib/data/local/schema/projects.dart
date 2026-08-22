import 'package:aularaiz/data/local/schema/teaching_groups.dart';
import 'package:drift/drift.dart';

class Projects extends Table {
  late final id = text()();
  late final groupId = text().references(
    TeachingGroups,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final title = text()();
  late final lifecycle = integer()();
  late final methodology = integer()();
  late final formativeField = integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
