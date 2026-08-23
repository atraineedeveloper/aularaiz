import 'package:aularaiz/domain/student/student_sex.dart';
import 'package:drift/drift.dart';

@DataClassName('StudentRow')
class Students extends Table {
  late final id = text()();
  late final givenNames = text()();
  late final firstSurname = text()();
  late final secondSurname = text().nullable()();
  late final sex = intEnum<StudentSex>().nullable()();
  late final birthDate = dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
