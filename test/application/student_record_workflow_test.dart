import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/student_record/add_student_record_entry.dart';
import 'package:aularaiz/application/student_record/update_student_record.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Student student;
  late _MemoryStudentRepository studentRepository;
  late _MemoryStudentRecordRepository recordRepository;

  setUp(() {
    student = Student(
      id: 'student-1',
      givenNames: 'Ana',
      firstSurname: 'López',
    );
    studentRepository = _MemoryStudentRepository(student);
    recordRepository = _MemoryStudentRecordRepository();
  });

  test('updates and normalizes pedagogical profile', () async {
    final useCase = UpdateStudentRecord(
      studentRepository: studentRepository,
      studentRecordRepository: recordRepository,
    );

    final record = await useCase(
      studentId: student.id,
      strengths: '  Explica sus estrategias.  ',
      difficulties: '  Requiere más tiempo para leer.  ',
      supports: '  Organizadores visuales.  ',
    );

    expect(record.strengths, 'Explica sus estrategias.');
    expect(record.difficulties, 'Requiere más tiempo para leer.');
    expect(record.supports, 'Organizadores visuales.');
    expect(recordRepository.record, same(record));
  });

  test('adds chronological family agreement with normalized data', () async {
    final useCase = AddStudentRecordEntry(
      studentRepository: studentRepository,
      studentRecordRepository: recordRepository,
      idGenerator: _FixedIdGenerator('entry-1'),
    );

    final entry = await useCase(
      studentId: student.id,
      kind: StudentRecordEntryKind.familyAgreement,
      occurredAt: DateTime(2026, 8, 22, 17, 30),
      text: '  Leer quince minutos al día en casa.  ',
    );

    expect(entry.id, 'entry-1');
    expect(entry.kind, StudentRecordEntryKind.familyAgreement);
    expect(entry.text, 'Leer quince minutos al día en casa.');
    expect(entry.occurredAt.isUtc, isTrue);
    expect(recordRepository.entries.single, same(entry));
  });

  test('does not create orphan record data for missing student', () async {
    final missingStudents = _MemoryStudentRepository(null);
    final update = UpdateStudentRecord(
      studentRepository: missingStudents,
      studentRecordRepository: recordRepository,
    );
    final addEntry = AddStudentRecordEntry(
      studentRepository: missingStudents,
      studentRecordRepository: recordRepository,
      idGenerator: _FixedIdGenerator('entry-orphan'),
    );

    expect(
      () => update(studentId: 'missing', strengths: 'Fortaleza'),
      throwsStateError,
    );
    expect(
      () => addEntry(
        studentId: 'missing',
        kind: StudentRecordEntryKind.observation,
        occurredAt: DateTime(2026, 8, 22),
        text: 'Observación',
      ),
      throwsStateError,
    );
    expect(recordRepository.record, isNull);
    expect(recordRepository.entries, isEmpty);
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

final class _MemoryStudentRecordRepository implements StudentRecordRepository {
  StudentRecord? record;
  final List<StudentRecordEntry> entries = [];

  @override
  Future<StudentRecord?> find(String studentId) async =>
      record?.studentId == studentId ? record : null;

  @override
  Future<void> save(StudentRecord value) async {
    record = value;
  }

  @override
  Future<List<StudentRecordEntry>> listEntries(String studentId) async =>
      entries.where((entry) => entry.studentId == studentId).toList();

  @override
  Future<void> addEntry(StudentRecordEntry entry) async {
    entries.add(entry);
  }
}

final class _FixedIdGenerator implements IdGenerator {
  _FixedIdGenerator(this.id);

  final String id;

  @override
  String newId() => id;
}
