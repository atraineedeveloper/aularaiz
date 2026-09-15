import 'package:aularaiz/data/local/schema/attendance_days.dart';
import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/data/local/schema/sync_metadata_columns.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:drift/drift.dart';

class AttendanceEntries extends Table with SyncMetadataColumns {
  late final attendanceDayId = text().references(
    AttendanceDays,
    #id,
    onDelete: KeyAction.cascade,
  )();
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final status = textEnum<AttendanceStatus>()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    attendanceDayId,
    studentId,
  };
}
