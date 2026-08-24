import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/student/enrollment.dart';

final class ReactivateStudentInGroup {
  ReactivateStudentInGroup({
    required EnrollStudent enrollStudent,
    required IdGenerator idGenerator,
  }) : _enrollStudent = enrollStudent,
       _idGenerator = idGenerator;

  final EnrollStudent _enrollStudent;
  final IdGenerator _idGenerator;

  Future<EnrollStudentResult> preview({
    required String studentId,
    required String groupId,
    required PrimaryGrade grade,
    required int listNumber,
    required DateTime startsOn,
  }) {
    return _enrollStudent.validate(
      _candidate(
        studentId: studentId,
        groupId: groupId,
        grade: grade,
        listNumber: listNumber,
        startsOn: startsOn,
      ),
    );
  }

  Future<EnrollStudentResult> call({
    required String studentId,
    required String groupId,
    required PrimaryGrade grade,
    required int listNumber,
    required DateTime startsOn,
  }) {
    return _enrollStudent(
      _candidate(
        studentId: studentId,
        groupId: groupId,
        grade: grade,
        listNumber: listNumber,
        startsOn: startsOn,
      ),
    );
  }

  Enrollment _candidate({
    required String studentId,
    required String groupId,
    required PrimaryGrade grade,
    required int listNumber,
    required DateTime startsOn,
  }) {
    return Enrollment(
      id: _idGenerator.newId(),
      studentId: studentId,
      groupId: groupId,
      grade: grade,
      listNumber: listNumber,
      startsOn: startsOn,
    );
  }
}
