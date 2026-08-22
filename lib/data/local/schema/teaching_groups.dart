import 'package:aularaiz/data/local/schema/school_years.dart';
import 'package:aularaiz/data/local/schema/schools.dart';
import 'package:drift/drift.dart';

@DataClassName('TeachingGroupRow')
class TeachingGroups extends Table {
  late final id = text()();
  late final schoolId = text().references(
    Schools,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final schoolYearId = text().references(
    SchoolYears,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final name = text()();
  late final shift = text().nullable()();
  late final scheduleStartMinutes = integer().nullable()();
  late final scheduleEndMinutes = integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
