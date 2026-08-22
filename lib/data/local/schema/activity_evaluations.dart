import 'package:aularaiz/data/local/schema/activities.dart';
// Drift resolves ActivityRoster from the composite foreign key in customConstraints.
// ignore: unused_import
import 'package:aularaiz/data/local/schema/activity_roster.dart';
import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:drift/drift.dart';

@DataClassName('ActivityEvaluationRow')
class ActivityEvaluations extends Table {
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
  late final deliveryStatus = textEnum<DeliveryStatus>()();
  late final achievement = textEnum<AchievementLevel>().nullable()();
  late final observation = text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{activityId, studentId};

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY (activity_id, student_id) '
        'REFERENCES activity_roster (activity_id, student_id)',
    "CHECK (delivery_status = 'delivered' OR achievement IS NULL)",
  ];
}
