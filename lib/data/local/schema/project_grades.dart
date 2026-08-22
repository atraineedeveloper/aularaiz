import 'package:aularaiz/data/local/schema/projects.dart';
import 'package:drift/drift.dart';

class ProjectGrades extends Table {
  late final projectId = text().references(
    Projects,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final grade = integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{projectId, grade};
}
