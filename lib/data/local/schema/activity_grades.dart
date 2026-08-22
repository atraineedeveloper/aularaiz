import 'package:aularaiz/data/local/schema/activities.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:drift/drift.dart';

class ActivityGrades extends Table {
  late final activityId = text().references(
    Activities,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final grade = textEnum<PrimaryGrade>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{activityId, grade};
}
