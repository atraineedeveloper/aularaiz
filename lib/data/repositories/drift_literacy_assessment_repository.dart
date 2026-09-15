import 'package:aularaiz/application/contracts/literacy_assessment_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:drift/drift.dart';

final class DriftLiteracyAssessmentRepository
    implements LiteracyAssessmentRepository {
  DriftLiteracyAssessmentRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<void> save(LiteracyAssessment assessment) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
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
            deletedAt: const Value(null),
            updatedAt: SyncMetadataValues.updated(timestamp),
            updatedByDeviceId: deviceId,
          ),
        );
  }

  @override
  Future<void> delete(String id) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await (database.update(
      database.literacyAssessments,
    )..where((table) => table.id.equals(id))).write(
      LiteracyAssessmentsCompanion(
        deletedAt: SyncMetadataValues.deleted(timestamp),
        updatedAt: SyncMetadataValues.updated(timestamp),
        updatedByDeviceId: deviceId,
      ),
    );
  }

  @override
  Future<LiteracyAssessment?> findById(String id) async {
    final row =
        await (database.select(database.literacyAssessments)
              ..where((table) => table.id.equals(id))
              ..where((table) => table.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<LiteracyAssessment>> listForStudent(String studentId) async {
    final rows =
        await (database.select(database.literacyAssessments)
              ..where((table) => table.studentId.equals(studentId))
              ..where((table) => table.deletedAt.isNull())
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
              ..where((table) => table.deletedAt.isNull())
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
