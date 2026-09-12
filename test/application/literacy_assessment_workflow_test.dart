import 'package:aularaiz/application/contracts/literacy_assessment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/literacy/delete_literacy_assessment.dart';
import 'package:aularaiz/application/literacy/save_literacy_assessment.dart';
import 'package:aularaiz/application/literacy/update_literacy_assessment.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Student student;
  late _MemoryStudentRepository studentRepository;
  late _MemoryLiteracyAssessmentRepository literacyRepository;

  setUp(() {
    student = Student(
      id: 'student-1',
      givenNames: 'Ana',
      firstSurname: 'Lopez',
    );
    studentRepository = _MemoryStudentRepository(student);
    literacyRepository = _MemoryLiteracyAssessmentRepository();
  });

  test('saves literacy assessment for an existing student', () async {
    final useCase = SaveLiteracyAssessment(
      studentRepository: studentRepository,
      repository: literacyRepository,
      idGenerator: _FixedIdGenerator('literacy-1'),
    );

    final assessment = await useCase(
      studentId: student.id,
      assessedAt: DateTime(2026, 9, 12),
      writingLevel: WritingLevel.syllabic,
      readingLevel: ReadingLevel.wordByWord,
      notes: '  Avanza.  ',
    );

    expect(assessment.id, 'literacy-1');
    expect(assessment.notes, 'Avanza.');
    expect(literacyRepository.items.single, same(assessment));
  });

  test('updates literacy assessment without changing its id', () async {
    final original = LiteracyAssessment(
      id: 'literacy-1',
      studentId: student.id,
      assessedAt: DateTime(2026, 9, 12),
      writingLevel: WritingLevel.syllabic,
      readingLevel: ReadingLevel.syllabic,
    );
    await literacyRepository.save(original);

    final updated =
        await UpdateLiteracyAssessment(repository: literacyRepository)(
          id: original.id,
          assessedAt: DateTime(2026, 11, 10),
          writingLevel: WritingLevel.syllabicAlphabetic,
          readingLevel: ReadingLevel.wordByWord,
          notes: 'Lectura palabra por palabra.',
        );

    expect(updated.id, original.id);
    expect(updated.studentId, original.studentId);
    expect(updated.assessedAt, DateTime(2026, 11, 10).toUtc());
    expect(
      literacyRepository.items.single.readingLevel,
      ReadingLevel.wordByWord,
    );
  });

  test('deletes literacy assessment', () async {
    await literacyRepository.save(
      LiteracyAssessment(
        id: 'literacy-1',
        studentId: student.id,
        assessedAt: DateTime(2026, 9, 12),
        writingLevel: WritingLevel.alphabetic,
        readingLevel: ReadingLevel.fluent,
      ),
    );

    await DeleteLiteracyAssessment(repository: literacyRepository)(
      'literacy-1',
    );

    expect(literacyRepository.items, isEmpty);
  });

  test('does not create assessment for missing student', () async {
    final useCase = SaveLiteracyAssessment(
      studentRepository: _MemoryStudentRepository(null),
      repository: literacyRepository,
      idGenerator: _FixedIdGenerator('literacy-orphan'),
    );

    await expectLater(
      useCase(
        studentId: 'missing',
        assessedAt: DateTime(2026, 9, 12),
        writingLevel: WritingLevel.syllabic,
        readingLevel: ReadingLevel.syllabic,
      ),
      throwsStateError,
    );
    expect(literacyRepository.items, isEmpty);
  });
}

final class _MemoryStudentRepository implements StudentRepository {
  _MemoryStudentRepository(this.student);

  final Student? student;

  @override
  Future<Student?> findById(String id) async =>
      student != null && student!.id == id ? student : null;

  @override
  Future<List<Student>> listAll() async =>
      student == null ? const [] : [student!];

  @override
  Future<void> save(Student student) async {}
}

final class _MemoryLiteracyAssessmentRepository
    implements LiteracyAssessmentRepository {
  final List<LiteracyAssessment> items = [];

  @override
  Future<void> save(LiteracyAssessment assessment) async {
    items.removeWhere((item) => item.id == assessment.id);
    items.add(assessment);
  }

  @override
  Future<void> delete(String id) async {
    items.removeWhere((item) => item.id == id);
  }

  @override
  Future<LiteracyAssessment?> findById(String id) async =>
      items.where((item) => item.id == id).firstOrNull;

  @override
  Future<List<LiteracyAssessment>> listForStudent(String studentId) async =>
      items.where((item) => item.studentId == studentId).toList();

  @override
  Future<LiteracyAssessment?> latestForStudent(String studentId) async =>
      (await listForStudent(studentId)).firstOrNull;
}

final class _FixedIdGenerator implements IdGenerator {
  _FixedIdGenerator(this.id);

  final String id;

  @override
  String newId() => id;
}
