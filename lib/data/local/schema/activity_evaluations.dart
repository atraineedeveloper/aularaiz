import 'package:aularaiz/data/local/schema/activities.dart';
import 'package:aularaiz/data/local/schema/students.dart';
import 'package:drift/drift.dart';

class ActivityEvaluations extends Table {
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
  late final deliveryStatus = integer()();
  late final achievement = integer().nullable()();
  late final observation = text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{activityId, studentId};
}
