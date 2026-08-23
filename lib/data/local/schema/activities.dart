import 'package:aularaiz/data/local/schema/projects.dart';
import 'package:drift/drift.dart';

@DataClassName('ActivityRow')
class Activities extends Table {
  late final id = text()();
  late final projectId = text().references(
    Projects,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final identifier = text().nullable()();
  late final title = text()();
  late final occursOn = dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
