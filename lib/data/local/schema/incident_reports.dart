import 'package:aularaiz/data/local/schema/schools.dart';
import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:aularaiz/data/local/schema/teaching_groups.dart';
import 'package:aularaiz/domain/incident/incident_category.dart';
import 'package:aularaiz/domain/incident/incident_status.dart';
import 'package:drift/drift.dart';

@DataClassName('IncidentReportRow')
class IncidentReports extends Table with SyncMetadataColumns {
  late final id = text()();
  late final schoolId = text().references(
    Schools,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final groupId = text().nullable().references(
    TeachingGroups,
    #id,
    onDelete: KeyAction.setNull,
  )();
  late final occurredAt = dateTime()();
  late final category = textEnum<IncidentCategory>()();
  late final description = text()();
  late final actionTaken = text().nullable()();
  late final followUpNote = text().nullable()();
  late final familyNotified = boolean().withDefault(const Constant(false))();
  late final leadershipNotified = boolean().withDefault(
    const Constant(false),
  )();
  late final status = textEnum<IncidentStatus>()();
  late final correctedAt = dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
