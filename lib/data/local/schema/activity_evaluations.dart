import 'package:aularaiz/data/local/schema/activities.dart';
import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
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
  late final deliveryStatus = textEnum<DeliveryStatus>()();
  late final achievement = textEnum<AchievementLevel>().nullable()();
  late final observation = text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{activityId, studentId};
}
