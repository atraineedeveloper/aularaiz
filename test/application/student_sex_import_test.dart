import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/application/student_import/student_import_preview_builder.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student/student_sex.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StudentImportPreviewBuilder builder;
  late TeachingGroup group;

  setUp(() {
    final schoolYear = SchoolYear(
      id: 'year-1',
      label: '2026-2027',
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2027, 7, 9),
    );
    group = TeachingGroup(
      id: 'group-1',
      schoolId: 'school-1',
      schoolYearId: schoolYear.id,
      name: '5° A',
      grades: {PrimaryGrade.fifth},
    );
    builder = StudentImportPreviewBuilder(
      schoolYearRepository: _SchoolYearRepository(schoolYear),
      enrollmentRepository: _EmptyEnrollmentRepository(),
      studentRepository: _EmptyStudentRepository(),
    );
  });

  test('imports Masculino and Femenino into typed student sex values', () async {
    final preview = await builder.build(
      group: group,
      sourceName: 'alumnos.csv',
      sheetName: null,
      drafts: const [
        StudentImportDraft(
          sourceRow: 2,
          givenNames: 'Luis',
          firstSurname: 'Pérez',
          secondSurname: '',
          sexText: 'Masculino',
          birthDateText: '',
          gradeText: '5',
          listNumberText: '1',
        ),
        StudentImportDraft(
          sourceRow: 3,
          givenNames: 'Ana',
          firstSurname: 'López',
          secondSurname: '',
          sexText: 'Femenino',
          birthDateText: '',
          gradeText: '5',
          listNumberText: '2',
        ),
      ],
    );

    expect(preview.canConfirm, isTrue);
    expect(preview.rows[0].sex, StudentSex.male);
    expect(preview.rows[1].sex, StudentSex.female);
  });

  test('blank sex remains compatible while invalid values are rejected', () async {
    final preview = await builder.build(
      group: group,
      sourceName: 'alumnos.csv',
      sheetName: null,
      drafts: const [
        StudentImportDraft(
          sourceRow: 2,
          givenNames: 'Luis',
          firstSurname: 'Pérez',
          secondSurname: '',
          birthDateText: '',
          gradeText: '5',
          listNumberText: '1',
        ),
        StudentImportDraft(
          sourceRow: 3,
          givenNames: 'Ana',
          firstSurname: 'López',
          secondSurname: '',
          sexText: 'desconocido',
          birthDateText: '',
          gradeText: '5',
          listNumberText: '2',
        ),
      ],
    );

    expect(preview.rows[0].sex, isNull);
    expect(preview.rows[0].issues, isNot(contains(StudentImportIssue.invalidSex)));
    expect(preview.rows[1].issues, contains(StudentImportIssue.invalidSex));
    expect(preview.canConfirm, isFalse);
  });
}

final class _SchoolYearRepository implements SchoolYearRepository {
  _SchoolYearRepository(this.schoolYear);

  final SchoolYear schoolYear;

  @override
  Future<SchoolYear?> findById(String id) async =>
      id == schoolYear.id ? schoolYear : null;
}

final class _EmptyEnrollmentRepository implements EnrollmentRepository {
  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async => const [];

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async => const [];

  @override
  Future<void> save(Enrollment enrollment) async {}
}

final class _EmptyStudentRepository implements StudentRepository {
  @override
  Future<Student?> findById(String id) async => null;

  @override
  Future<List<Student>> listAll() async => const [];

  @override
  Future<void> save(Student student) async {}
}
