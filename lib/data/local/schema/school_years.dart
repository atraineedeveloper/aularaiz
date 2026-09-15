import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:drift/drift.dart';

@DataClassName('SchoolYearRow')
class SchoolYears extends Table with SyncMetadataColumns {
  late final id = text()();
  late final label = text()();
  late final startsOn = dateTime()();
  late final endsOn = dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK (ends_on >= starts_on)',
  ];
}
