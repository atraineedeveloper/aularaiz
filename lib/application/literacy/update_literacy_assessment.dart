import 'package:aularaiz/application/contracts/literacy_assessment_repository.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';

final class UpdateLiteracyAssessment {
  UpdateLiteracyAssessment({required LiteracyAssessmentRepository repository})
    : _repository = repository;

  final LiteracyAssessmentRepository _repository;

  Future<LiteracyAssessment> call({
    required String id,
    required DateTime assessedAt,
    required WritingLevel writingLevel,
    required ReadingLevel readingLevel,
    String? notes,
  }) async {
    final current = await _repository.findById(id);
    if (current == null) {
      throw StateError('Literacy assessment does not exist.');
    }

    final updated = LiteracyAssessment(
      id: current.id,
      studentId: current.studentId,
      assessedAt: assessedAt,
      writingLevel: writingLevel,
      readingLevel: readingLevel,
      notes: notes,
    );
    await _repository.save(updated);
    return updated;
  }
}
