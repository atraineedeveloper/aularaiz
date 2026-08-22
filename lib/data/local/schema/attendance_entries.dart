import 'package:aularaiz/data/local/schema/attendance_days.dart';
import 'package:aularaiz/data/local/schema/students.dart';
import 'package:drift/drift.dart';

class AttendanceEntries extends Table {
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
  late final status = integer()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
    attendanceDayId,
    studentId,
  };
}
