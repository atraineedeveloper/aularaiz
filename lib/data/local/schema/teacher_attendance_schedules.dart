import 'package:aularaiz/data/local/schema/schools.dart';
import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:drift/drift.dart';

@DataClassName('TeacherAttendanceScheduleRow')
class TeacherAttendanceSchedules extends Table with SyncMetadataColumns {
  late final schoolId = text().references(
    Schools,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final expectedArrivalMinute = integer().nullable()();
  late final expectedDepartureMinute = integer().nullable()();
  late final arrivalGraceMinutes = integer().withDefault(const Constant(10))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{schoolId};
}
