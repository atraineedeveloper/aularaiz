import 'package:aularaiz/data/local/schema/activities.dart';
import 'package:aularaiz/data/local/schema/activity_grades.dart';
import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:drift/drift.dart';

class ActivityRoster extends Table {
  late final activityId = text().references(
    Activities,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final grade = textEnum<PrimaryGrade>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{activityId, studentId};

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY (activity_id, grade) '
        'REFERENCES activity_grades (activity_id, grade)',
  ];
}
