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
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SchoolYear schoolYear;
  late TeachingGroup group;
  late Student existingStudent;
  late Enrollment existingEnrollment;
  late StudentImportPreviewBuilder builder;

  setUp(() {
    schoolYear = SchoolYear(
      id: 'year-1',
      label: '2026-2027',
      startsOn: DateTime(2026, 8, 1),
      endsOn: DateTime(2027, 7, 31),
    );
    group = TeachingGroup(
      id: 'group-1',
      schoolId: 'school-1',
      schoolYearId: schoolYear.id,
      name: '5° A',
      grades: {PrimaryGrade.fifth},
    );
    existingStudent = Student(
      id: 'student-existing',
      givenNames: 'Elena',
      firstSurname: 'Ruiz',
      secondSurname: 'López',
      birthDate: DateTime(2016, 4, 2),
    );
    existingEnrollment = Enrollment(
      id: 'enrollment-existing',
      studentId: existingStudent.id,
      groupId: group.id,
      grade: PrimaryGrade.fifth,
      listNumber: 1,
      startsOn: schoolYear.startsOn,
    );
    builder = StudentImportPreviewBuilder(
      schoolYearRepository: _SchoolYearRepository(schoolYear),
      enrollmentRepository: _EnrollmentRepository([existingEnrollment]),
      studentRepository: _StudentRepository([existingStudent]),
    );
  });

  test(
    'duplicate list numbers among included rows block confirmation',
    () async {
      final preview = await builder.build(
        group: group,
        sourceName: 'lista.csv',
        sheetName: null,
        drafts: const [
          StudentImportDraft(
            sourceRow: 2,
            givenNames: 'Ana',
            firstSurname: 'Pérez',
            secondSurname: '',
            birthDateText: '12/03/2016',
            gradeText: '5°',
            listNumberText: '2',
          ),
          StudentImportDraft(
            sourceRow: 3,
            givenNames: 'Bruno',
            firstSurname: 'Díaz',
            secondSurname: '',
            birthDateText: '',
            gradeText: 'quinto',
            listNumberText: '2',
          ),
        ],
      );

      expect(preview.canConfirm, isFalse);
      expect(preview.errorCount, 2);
      expect(
        preview.rows.first.issues,
        contains(StudentImportIssue.duplicateListNumberInFile),
      );
      expect(
        preview.rows.last.issues,
        contains(StudentImportIssue.duplicateListNumberInFile),
      );
    },
  );

  test('excluding one duplicate makes the remaining row importable', () async {
    final preview = await builder.build(
      group: group,
      sourceName: 'lista.csv',
      sheetName: null,
      drafts: const [
        StudentImportDraft(
          sourceRow: 2,
          givenNames: 'Ana',
          firstSurname: 'Pérez',
          secondSurname: '',
          birthDateText: '12/03/2016',
          gradeText: '5',
          listNumberText: '2',
        ),
        StudentImportDraft(
          sourceRow: 3,
          givenNames: 'Bruno',
          firstSurname: 'Díaz',
          secondSurname: '',
          birthDateText: '',
          gradeText: '5',
          listNumberText: '2',
          included: false,
        ),
      ],
    );

    expect(preview.canConfirm, isTrue);
    expect(preview.includedCount, 1);
    expect(preview.readyCount, 1);
    expect(preview.errorCount, 0);
    expect(preview.rows.first.birthDate, DateTime(2016, 3, 12));
  });

  test(
    'existing list number and unsupported grade are blocking errors',
    () async {
      final preview = await builder.build(
        group: group,
        sourceName: 'lista.csv',
        sheetName: null,
        drafts: const [
          StudentImportDraft(
            sourceRow: 2,
            givenNames: 'Ana',
            firstSurname: 'Pérez',
            secondSurname: '',
            birthDateText: '',
            gradeText: '5',
            listNumberText: '1',
          ),
          StudentImportDraft(
            sourceRow: 3,
            givenNames: 'Bruno',
            firstSurname: 'Díaz',
            secondSurname: '',
            birthDateText: '',
            gradeText: '4',
            listNumberText: '8',
          ),
        ],
      );

      expect(
        preview.rows[0].issues,
        contains(StudentImportIssue.listNumberAlreadyAssigned),
      );
      expect(
        preview.rows[1].issues,
        contains(StudentImportIssue.gradeNotOffered),
      );
      expect(preview.canConfirm, isFalse);
    },
  );

  test('possible existing identity is a warning and does not block', () async {
    final preview = await builder.build(
      group: group,
      sourceName: 'lista.xlsx',
      sheetName: 'Alumnos',
      drafts: const [
        StudentImportDraft(
          sourceRow: 2,
          givenNames: '  ELENA ',
          firstSurname: 'Ruíz',
          secondSurname: 'López',
          birthDateText: '02/04/2016',
          gradeText: '5',
          listNumberText: '2',
        ),
      ],
    );

    expect(preview.canConfirm, isTrue);
    expect(preview.warningCount, 1);
    expect(
      preview.rows.single.issues,
      contains(StudentImportIssue.possibleDuplicateExisting),
    );
  });

  test('invalid and future dates are blocking errors', () async {
    final preview = await builder.build(
      group: group,
      sourceName: 'lista.csv',
      sheetName: null,
      drafts: const [
        StudentImportDraft(
          sourceRow: 2,
          givenNames: 'Ana',
          firstSurname: 'Pérez',
          secondSurname: '',
          birthDateText: '31/02/2016',
          gradeText: '5',
          listNumberText: '2',
        ),
        StudentImportDraft(
          sourceRow: 3,
          givenNames: 'Bruno',
          firstSurname: 'Díaz',
          secondSurname: '',
          birthDateText: '01/01/2099',
          gradeText: '5',
          listNumberText: '3',
        ),
      ],
    );

    expect(
      preview.rows[0].issues,
      contains(StudentImportIssue.invalidBirthDate),
    );
    expect(
      preview.rows[1].issues,
      contains(StudentImportIssue.birthDateInFuture),
    );
    expect(preview.canConfirm, isFalse);
  });
}

final class _SchoolYearRepository implements SchoolYearRepository {
  _SchoolYearRepository(this.value);

  final SchoolYear value;

  @override
  Future<SchoolYear?> findById(String id) async =>
      id == value.id ? value : null;
}

final class _EnrollmentRepository implements EnrollmentRepository {
  _EnrollmentRepository(this.values);

  final List<Enrollment> values;

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async =>
      values.where((value) => value.groupId == groupId).toList();

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async =>
      values.where((value) => value.studentId == studentId).toList();

  @override
  Future<void> save(Enrollment enrollment) async {}
}

final class _StudentRepository implements StudentRepository {
  _StudentRepository(this.values);

  final List<Student> values;

  @override
  Future<Student?> findById(String id) async {
    for (final student in values) {
      if (student.id == id) return student;
    }
    return null;
  }

  @override
  Future<List<Student>> listAll() async => List<Student>.of(values);

  @override
  Future<void> save(Student student) async {}
}
