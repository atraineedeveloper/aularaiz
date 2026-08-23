import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_enrollment_batch_writer.dart';
import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/application/student_import/student_import_preview_builder.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';

final class StudentImportValidationException implements Exception {
  const StudentImportValidationException(this.preview);

  final StudentImportPreview preview;

  @override
  String toString() => 'Student import contains blocking validation errors.';
}

final class ImportStudents {
  ImportStudents({
    required StudentImportPreviewBuilder previewBuilder,
    required SchoolYearRepository schoolYearRepository,
    required StudentEnrollmentBatchWriter batchWriter,
    required IdGenerator idGenerator,
  }) : _previewBuilder = previewBuilder,
       _schoolYearRepository = schoolYearRepository,
       _batchWriter = batchWriter,
       _idGenerator = idGenerator;

  final StudentImportPreviewBuilder _previewBuilder;
  final SchoolYearRepository _schoolYearRepository;
  final StudentEnrollmentBatchWriter _batchWriter;
  final IdGenerator _idGenerator;

  Future<StudentImportResult> call({
    required TeachingGroup group,
    required String sourceName,
    required String? sheetName,
    required List<StudentImportDraft> drafts,
  }) async {
    final preview = await _previewBuilder.build(
      group: group,
      sourceName: sourceName,
      sheetName: sheetName,
      drafts: drafts,
    );
    if (!preview.canConfirm) {
      throw StudentImportValidationException(preview);
    }

    final schoolYear = await _schoolYearRepository.findById(group.schoolYearId);
    if (schoolYear == null) {
      throw StateError('School year does not exist.');
    }

    final entries = <NewStudentEnrollment>[];
    for (final row in preview.rows) {
      if (!row.draft.included) continue;
      final grade = row.grade;
      final listNumber = row.listNumber;
      if (grade == null || listNumber == null || row.hasErrors) {
        throw StudentImportValidationException(preview);
      }

      final studentId = _idGenerator.newId();
      final student = Student(
        id: studentId,
        givenNames: row.draft.givenNames.trim(),
        firstSurname: row.draft.firstSurname.trim(),
        secondSurname: _optional(row.draft.secondSurname),
        sex: row.sex,
        birthDate: row.birthDate,
      );
      final enrollment = Enrollment(
        id: _idGenerator.newId(),
        studentId: studentId,
        groupId: group.id,
        grade: grade,
        listNumber: listNumber,
        startsOn: schoolYear.startsOn,
      );
      entries.add(
        NewStudentEnrollment(student: student, enrollment: enrollment),
      );
    }

    await _batchWriter.saveBatch(entries);
    return StudentImportResult(importedCount: entries.length);
  }

  String? _optional(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
