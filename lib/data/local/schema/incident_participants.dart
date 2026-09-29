import 'package:aularaiz/data/local/schema/incident_reports.dart';
import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:drift/drift.dart';

class IncidentParticipants extends Table with SyncMetadataColumns {
  late final incidentId = text().references(
    IncidentReports,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{incidentId, studentId};
}
