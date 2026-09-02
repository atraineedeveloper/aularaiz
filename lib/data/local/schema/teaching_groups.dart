import 'package:aularaiz/data/local/schema/school_years.dart';
import 'package:aularaiz/data/local/schema/schools.dart';
import 'package:aularaiz/domain/teacher/teaching_role.dart';
import 'package:drift/drift.dart';

@DataClassName('TeachingGroupRow')
class TeachingGroups extends Table {
  late final id = text()();
  late final schoolId = text().references(
    Schools,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final schoolYearId = text().references(
    SchoolYears,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final name = text()();
  late final shift = text().nullable()();
  late final scheduleStartMinutes = integer().nullable()();
  late final scheduleEndMinutes = integer().nullable()();
  late final contractStartsOn = dateTime().nullable()();
  late final contractEndsOn = dateTime().nullable()();
  late final teachingRole = textEnum<TeachingRole>().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};

  @override
  List<String> get customConstraints => <String>[
    'CHECK ((schedule_start_minutes IS NULL AND schedule_end_minutes IS NULL) '
        'OR (schedule_start_minutes IS NOT NULL AND schedule_end_minutes IS NOT NULL '
        'AND schedule_start_minutes >= 0 AND schedule_start_minutes < 1440 '
        'AND schedule_end_minutes > schedule_start_minutes '
        'AND schedule_end_minutes < 1440))',
    'CHECK ((contract_starts_on IS NULL AND contract_ends_on IS NULL) '
        'OR (contract_starts_on IS NOT NULL AND contract_ends_on IS NOT NULL '
        'AND contract_ends_on >= contract_starts_on))',
  ];
}
