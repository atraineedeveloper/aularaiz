import 'package:aularaiz/data/local/schema/students.dart';
import 'package:aularaiz/data/local/schema/teaching_groups.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:drift/drift.dart';

@DataClassName('EnrollmentRow')
class Enrollments extends Table {
  late final id = text()();
  late final studentId = text().references(
    Students,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final groupId = text().references(
    TeachingGroups,
    #id,
    onDelete: KeyAction.restrict,
  )();
  late final grade = textEnum<PrimaryGrade>()();
  late final listNumber = integer()();
  late final startsOn = dateTime()();
  late final endsOn = dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
