import 'package:aularaiz/data/local/schema/teaching_groups.dart';
import 'package:drift/drift.dart';

class AttendanceDays extends Table {
  late final id = text()();
  late final groupId = text().references(
    TeachingGroups,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final date = dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{groupId, date},
  ];
}
