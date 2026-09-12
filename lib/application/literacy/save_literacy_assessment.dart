import 'package:aularaiz/application/contracts/literacy_assessment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';

final class SaveLiteracyAssessment {
  SaveLiteracyAssessment({
    required StudentRepository studentRepository,
    required LiteracyAssessmentRepository repository,
    required IdGenerator idGenerator,
  }) : _studentRepository = studentRepository,
       _repository = repository,
       _idGenerator = idGenerator;

  final StudentRepository _studentRepository;
  final LiteracyAssessmentRepository _repository;
  final IdGenerator _idGenerator;

  Future<LiteracyAssessment> call({
    required String studentId,
    required DateTime assessedAt,
    required WritingLevel writingLevel,
    required ReadingLevel readingLevel,
    String? notes,
  }) async {
    final student = await _studentRepository.findById(studentId);
    if (student == null) {
      throw StateError('Student does not exist.');
    }

    final assessment = LiteracyAssessment(
      id: _idGenerator.newId(),
      studentId: studentId,
      assessedAt: assessedAt,
      writingLevel: writingLevel,
      readingLevel: readingLevel,
      notes: notes,
    );
    await _repository.save(assessment);
    return assessment;
  }
}
