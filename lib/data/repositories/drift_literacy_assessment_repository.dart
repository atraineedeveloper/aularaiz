import 'package:aularaiz/application/contracts/literacy_assessment_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:drift/drift.dart';

final class DriftLiteracyAssessmentRepository
    implements LiteracyAssessmentRepository {
  DriftLiteracyAssessmentRepository(this.database);

  final AppDatabase database;

  @override
  Future<void> save(LiteracyAssessment assessment) async {
    await database
        .into(database.literacyAssessments)
        .insertOnConflictUpdate(
          LiteracyAssessmentsCompanion(
            id: Value(assessment.id),
            studentId: Value(assessment.studentId),
            assessedAt: Value(assessment.assessedAt),
            writingLevel: Value(assessment.writingLevel),
            readingLevel: Value(assessment.readingLevel),
            notes: Value(assessment.notes),
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    await (database.delete(
      database.literacyAssessments,
    )..where((table) => table.id.equals(id))).go();
  }

  @override
  Future<LiteracyAssessment?> findById(String id) async {
    final row =
        await (database.select(database.literacyAssessments)
              ..where((table) => table.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<LiteracyAssessment>> listForStudent(String studentId) async {
    final rows =
        await (database.select(database.literacyAssessments)
              ..where((table) => table.studentId.equals(studentId))
              ..orderBy([
                (table) => OrderingTerm.desc(table.assessedAt),
                (table) => OrderingTerm.desc(table.id),
              ]))
            .get();
    return List<LiteracyAssessment>.unmodifiable(rows.map(_toDomain));
  }

  @override
  Future<LiteracyAssessment?> latestForStudent(String studentId) async {
    final row =
        await (database.select(database.literacyAssessments)
              ..where((table) => table.studentId.equals(studentId))
              ..orderBy([
                (table) => OrderingTerm.desc(table.assessedAt),
                (table) => OrderingTerm.desc(table.id),
              ])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  LiteracyAssessment _toDomain(LiteracyAssessmentRow row) {
    return LiteracyAssessment(
      id: row.id,
      studentId: row.studentId,
      assessedAt: row.assessedAt,
      writingLevel: row.writingLevel,
      readingLevel: row.readingLevel,
      notes: row.notes,
    );
  }
}
