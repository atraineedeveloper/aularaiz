import 'package:aularaiz/data/local/schema/teaching_groups.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:drift/drift.dart';

@DataClassName('ProjectRow')
class Projects extends Table {
  late final id = text()();
  late final groupId = text().references(
    TeachingGroups,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final title = text()();
  late final description = text().nullable()();
  late final startsOn = dateTime().nullable()();
  late final endsOn = dateTime().nullable()();
  late final observations = text().nullable()();
  late final lifecycle = textEnum<ProjectLifecycle>()();
  late final methodology = textEnum<ProjectMethodology>()();
  late final formativeField = textEnum<FormativeField>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
