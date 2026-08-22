import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:drift/drift.dart';

@DataClassName('SchoolRow')
class Schools extends Table {
  late final id = text()();
  late final name = text()();
  late final cct = text().nullable().unique()();
  late final organization = textEnum<SchoolOrganization>()();
  late final state = text().nullable()();
  late final municipality = text().nullable()();
  late final locality = text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
