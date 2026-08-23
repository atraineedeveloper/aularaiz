import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_enrollment_batch_writer.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/student_import/import_students.dart';
import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/application/student_import/student_import_preview_builder.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SchoolYear schoolYear;
  late TeachingGroup group;
  late _BatchWriter writer;
  late ImportStudents useCase;

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
    final schoolYears = _SchoolYearRepository(schoolYear);
    final previewBuilder = StudentImportPreviewBuilder(
      schoolYearRepository: schoolYears,
      enrollmentRepository: _EnrollmentRepository(),
      studentRepository: _StudentRepository(),
    );
    writer = _BatchWriter();
    useCase = ImportStudents(
      previewBuilder: previewBuilder,
      schoolYearRepository: schoolYears,
      batchWriter: writer,
      idGenerator: _IdGenerator([
        'student-1',
        'enrollment-1',
        'student-2',
        'enrollment-2',
      ]),
    );
  });

  test('valid rows are committed in one batch with normalized values', () async {
    final result = await useCase(
      group: group,
      sourceName: 'lista.csv',
      sheetName: null,
      drafts: const [
        StudentImportDraft(
          sourceRow: 2,
          givenNames: ' Ana ',
          firstSurname: ' Pérez ',
          secondSurname: ' López ',
          birthDateText: '12/03/2016',
          gradeText: '5',
          listNumberText: '2',
        ),
        StudentImportDraft(
          sourceRow: 3,
          givenNames: 'Bruno',
          firstSurname: 'Díaz',
          secondSurname: '   ',
          birthDateText: '',
          gradeText: 'quinto',
          listNumberText: '3',
        ),
      ],
    );

    expect(result.importedCount, 2);
    expect(writer.callCount, 1);
    expect(writer.lastEntries, hasLength(2));
    expect(writer.lastEntries[0].student.id, 'student-1');
    expect(writer.lastEntries[0].student.givenNames, 'Ana');
    expect(writer.lastEntries[0].student.firstSurname, 'Pérez');
    expect(writer.lastEntries[0].student.secondSurname, 'López');
    expect(writer.lastEntries[0].student.birthDate, DateTime(2016, 3, 12));
    expect(writer.lastEntries[0].enrollment.id, 'enrollment-1');
    expect(writer.lastEntries[0].enrollment.startsOn, schoolYear.startsOn);
    expect(writer.lastEntries[1].student.secondSurname, isNull);
  });

  test('invalid batch is rejected before the atomic writer is called', () async {
    await expectLater(
      useCase(
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
          ),
        ],
      ),
      throwsA(isA<StudentImportValidationException>()),
    );

    expect(writer.callCount, 0);
    expect(writer.lastEntries, isEmpty);
  });
}

final class _SchoolYearRepository implements SchoolYearRepository {
  _SchoolYearRepository(this.value);

  final SchoolYear value;

  @override
  Future<SchoolYear?> findById(String id) async => id == value.id ? value : null;
}

final class _EnrollmentRepository implements EnrollmentRepository {
  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async => const [];

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async => const [];

  @override
  Future<void> save(Enrollment enrollment) async {}
}

final class _StudentRepository implements StudentRepository {
  @override
  Future<Student?> findById(String id) async => null;

  @override
  Future<List<Student>> listAll() async => const [];

  @override
  Future<void> save(Student student) async {}
}

final class _BatchWriter implements StudentEnrollmentBatchWriter {
  var callCount = 0;
  List<NewStudentEnrollment> lastEntries = const [];

  @override
  Future<void> saveBatch(List<NewStudentEnrollment> entries) async {
    callCount++;
    lastEntries = List<NewStudentEnrollment>.of(entries);
  }
}

final class _IdGenerator implements IdGenerator {
  _IdGenerator(this.values);

  final List<String> values;
  var index = 0;

  @override
  String newId() => values[index++];
}
