import 'package:drift/drift.dart';

class Schools extends Table {
  late final id = text()();
  late final name = text()();
  late final cct = text().nullable().unique()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
