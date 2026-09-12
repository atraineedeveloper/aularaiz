import 'package:aularaiz/domain/literacy/literacy_assessment.dart';

abstract interface class LiteracyAssessmentRepository {
  Future<void> save(LiteracyAssessment assessment);

  Future<void> delete(String id);

  Future<LiteracyAssessment?> findById(String id);

  Future<List<LiteracyAssessment>> listForStudent(String studentId);

  Future<LiteracyAssessment?> latestForStudent(String studentId);
}
