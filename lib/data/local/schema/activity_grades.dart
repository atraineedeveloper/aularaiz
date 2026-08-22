import 'package:aularaiz/data/local/schema/activities.dart';
import 'package:drift/drift.dart';

class ActivityGrades extends Table {
  late final activityId = text().references(
    Activities,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final grade = integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{activityId, grade};
}
