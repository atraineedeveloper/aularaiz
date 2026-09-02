import 'package:drift/drift.dart';

/// Single local teacher profile for this installation.
///
/// The profile is installation-scoped: it never references a school so it
/// survives school creation and contract changes. Only the full name is
/// stored — no CURP, RFC, phone or other sensitive identifiers.
@DataClassName('TeacherProfileRow')
class TeacherProfiles extends Table {
  late final id = text()();
  late final fullName = text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
