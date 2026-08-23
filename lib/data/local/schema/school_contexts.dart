import 'package:aularaiz/data/local/schema/school_years.dart';
import 'package:aularaiz/data/local/schema/schools.dart';
import 'package:drift/drift.dart';

@DataClassName('SchoolContextRow')
class SchoolContexts extends Table {
  late final schoolId = text().references(
    Schools,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final schoolYearId = text().references(
    SchoolYears,
    #id,
    onDelete: KeyAction.restrict,
  )();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{schoolId};
}
