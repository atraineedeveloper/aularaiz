import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/literacy_assessment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/literacy/save_literacy_assessment.dart';
import 'package:aularaiz/application/literacy/update_literacy_assessment.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/features/literacy/presentation/literacy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads literacy summary and filters active and historical students',
    () async {
      final group = TeachingGroup(
        id: 'group-1',
        schoolId: 'school-1',
        schoolYearId: '2026',
        name: 'Grupo unitario',
        grades: {PrimaryGrade.first, PrimaryGrade.third},
      );
      final students = _StudentRepository([
        Student(id: 'student-1', givenNames: 'Ana', firstSurname: 'Lopez'),
        Student(id: 'student-2', givenNames: 'Luis', firstSurname: 'Perez'),
        Student(id: 'student-3', givenNames: 'Mia', firstSurname: 'Gomez'),
        Student(id: 'student-4', givenNames: 'Jose', firstSurname: 'Ramos'),
      ]);
      final enrollments = _EnrollmentRepository([
        Enrollment(
          id: 'enrollment-1',
          studentId: 'student-1',
          groupId: group.id,
          grade: PrimaryGrade.third,
          listNumber: 1,
          startsOn: DateTime(2026, 8, 24),
        ),
        Enrollment(
          id: 'enrollment-2',
          studentId: 'student-2',
          groupId: group.id,
          grade: PrimaryGrade.first,
          listNumber: 2,
          startsOn: DateTime(2026, 8, 24),
        ),
        Enrollment(
          id: 'enrollment-3',
          studentId: 'student-3',
          groupId: group.id,
          grade: PrimaryGrade.third,
          listNumber: 3,
          startsOn: DateTime(2026, 8, 24),
        ),
        Enrollment(
          id: 'enrollment-4',
          studentId: 'student-4',
          groupId: group.id,
          grade: PrimaryGrade.third,
          listNumber: 4,
          startsOn: DateTime(2026, 8, 24),
          endsOn: DateTime(2026, 9, 1),
        ),
      ]);
      final assessments = _LiteracyRepository([
        LiteracyAssessment(
          id: 'literacy-1',
          studentId: 'student-1',
          assessedAt: DateTime(2026, 9, 1),
          writingLevel: WritingLevel.syllabic,
          readingLevel: ReadingLevel.wordByWord,
        ),
        LiteracyAssessment(
          id: 'literacy-2',
          studentId: 'student-2',
          assessedAt: DateTime(2026, 9, 1),
          writingLevel: WritingLevel.alphabetic,
          readingLevel: ReadingLevel.fluent,
        ),
      ]);
      final controller = LiteracyController(
        enrollmentRepository: enrollments,
        studentRepository: students,
        literacyAssessmentRepository: assessments,
        saveLiteracyAssessment: SaveLiteracyAssessment(
          studentRepository: students,
          repository: assessments,
          idGenerator: _IdGenerator(),
        ),
        updateLiteracyAssessment: UpdateLiteracyAssessment(
          repository: assessments,
        ),
      );

      await controller.load(group, referenceDate: DateTime(2026, 9, 15));

      expect(controller.entries, hasLength(4));
      expect(controller.activeStudentCount, 3);
      expect(controller.historicalStudentCount, 1);
      expect(controller.assessedCount, 2);
      expect(controller.pendingCount, 1);
      expect(controller.prioritySupportCount, 1);

      controller.setFilter(LiteracyFilter.all);
      expect(controller.filteredEntries.map((entry) => entry.student.id), [
        'student-2',
        'student-1',
        'student-3',
      ]);

      controller.setFilter(LiteracyFilter.prioritySupport);
      expect(controller.filteredEntries.single.student.id, 'student-1');

      controller.setFilter(LiteracyFilter.pending);
      expect(controller.filteredEntries.single.student.id, 'student-3');

      controller.setFilter(LiteracyFilter.historical);
      expect(controller.filteredEntries.single.student.id, 'student-4');
    },
  );
}

final class _EnrollmentRepository implements EnrollmentRepository {
  _EnrollmentRepository(this.items);

  final List<Enrollment> items;

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async =>
      items.where((item) => item.groupId == groupId).toList();

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async =>
      items.where((item) => item.studentId == studentId).toList();

  @override
  Future<void> save(Enrollment enrollment) async {}
}

final class _StudentRepository implements StudentRepository {
  _StudentRepository(this.items);

  final List<Student> items;

  @override
  Future<Student?> findById(String id) async =>
      items.where((item) => item.id == id).firstOrNull;

  @override
  Future<List<Student>> listAll() async => items;

  @override
  Future<void> save(Student student) async {}
}

final class _LiteracyRepository implements LiteracyAssessmentRepository {
  _LiteracyRepository(this.items);

  final List<LiteracyAssessment> items;

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
  Future<LiteracyAssessment?> latestForStudent(String studentId) async {
    final studentItems = await listForStudent(studentId);
    if (studentItems.isEmpty) return null;
    studentItems.sort(
      (left, right) => right.assessedAt.compareTo(left.assessedAt),
    );
    return studentItems.first;
  }
}

final class _IdGenerator implements IdGenerator {
  var _next = 1;

  @override
  String newId() => 'literacy-${_next++}';
}
