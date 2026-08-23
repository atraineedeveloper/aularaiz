import 'package:aularaiz/data/local/schema/projects.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:drift/drift.dart';

@DataClassName('ProjectFormativeFieldRow')
class ProjectFormativeFields extends Table {
  late final projectId = text().references(
    Projects,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final formativeField = textEnum<FormativeField>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    projectId,
    formativeField,
  };
}
