import 'package:aularaiz/application/contracts/literacy_assessment_repository.dart';

final class DeleteLiteracyAssessment {
  DeleteLiteracyAssessment({required LiteracyAssessmentRepository repository})
    : _repository = repository;

  final LiteracyAssessmentRepository _repository;

  Future<void> call(String id) => _repository.delete(id);
}
