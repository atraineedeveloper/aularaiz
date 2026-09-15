import 'package:aularaiz/data/local/schema/school_years.dart';
import 'package:aularaiz/data/local/schema/schools.dart';
import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:drift/drift.dart';

@DataClassName('SchoolContextRow')
class SchoolContexts extends Table with SyncMetadataColumns {
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
