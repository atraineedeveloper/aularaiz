import 'package:aularaiz/data/local/schema/projects.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
import 'package:drift/drift.dart';

@DataClassName('ProjectArticulatingAxisRow')
class ProjectArticulatingAxes extends Table {
  late final projectId = text().references(
    Projects,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final articulatingAxis = textEnum<ArticulatingAxis>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    projectId,
    articulatingAxis,
  };
}
