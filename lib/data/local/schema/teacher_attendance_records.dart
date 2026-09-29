import 'package:aularaiz/data/local/schema/schools.dart';
import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:drift/drift.dart';

/// A teacher's daily arrival and departure at one school.
@DataClassName('TeacherAttendanceRow')
class TeacherAttendanceRecords extends Table with SyncMetadataColumns {
  late final id = text()();
  late final schoolId = text().references(
    Schools,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final attendanceDate = text()();
  late final arrivedAt = dateTime()();
  late final departedAt = dateTime().nullable()();
  late final notes = text().nullable()();
  late final correctedAt = dateTime().nullable()();
  late final expectedArrivalMinute = integer().nullable()();
  late final expectedDepartureMinute = integer().nullable()();
  late final arrivalGraceMinutes = integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{schoolId, attendanceDate},
  ];
}
