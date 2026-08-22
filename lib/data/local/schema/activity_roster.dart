import 'package:aularaiz/data/local/schema/activities.dart';
import 'package:aularaiz/data/local/schema/students.dart';
import 'package:drift/drift.dart';

class ActivityRoster extends Table {
  late final activityId = text().references(
    Activities,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final grade = integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{activityId, studentId};
}
