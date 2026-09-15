import 'package:aularaiz/data/local/schema/activities.dart';
import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:drift/drift.dart';

@DataClassName('ActivityFormativeFieldRow')
class ActivityFormativeFields extends Table with SyncMetadataColumns {
  late final activityId = text().references(
    Activities,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final formativeField = textEnum<FormativeField>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{activityId};
}
