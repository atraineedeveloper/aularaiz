import 'package:aularaiz/data/local/schema/projects.dart';
import 'package:drift/drift.dart';

class Activities extends Table {
  late final id = text()();
  late final projectId = text().references(
    Projects,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final title = text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
