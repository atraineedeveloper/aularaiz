import 'package:drift/drift.dart';

@DataClassName('SchoolYearRow')
class SchoolYears extends Table {
  late final id = text()();
  late final label = text()();
  late final startsOn = dateTime()();
  late final endsOn = dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
