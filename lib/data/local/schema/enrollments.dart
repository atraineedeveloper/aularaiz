// Drift resolves GroupGrades from the composite foreign key in customConstraints.
// ignore: unused_import
import 'package:aularaiz/data/local/schema/group_grades.dart';
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

  @override
  List<String> get customConstraints => <String>[
    'FOREIGN KEY (group_id, grade) '
        'REFERENCES group_grades (group_id, grade)',
    'CHECK (list_number > 0)',
    'CHECK (ends_on IS NULL OR ends_on >= starts_on)',
  ];
}
