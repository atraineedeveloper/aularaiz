import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/student_record/student_record.dart';
import 'package:aularaiz/domain/student_record/student_record_entry.dart';
import 'package:drift/drift.dart';

final class DriftStudentRecordRepository implements StudentRecordRepository {
  DriftStudentRecordRepository(this.database);

  final AppDatabase database;

  @override
  Future<StudentRecord?> find(String studentId) async {
    final row =
        await (database.select(database.studentRecords)
              ..where((table) => table.studentId.equals(studentId))
              ..limit(1))
            .getSingleOrNull();
    if (row == null) return null;
    return StudentRecord(
      studentId: row.studentId,
      strengths: row.strengths,
      difficulties: row.difficulties,
      supports: row.supports,
    );
  }

  @override
  Future<void> save(StudentRecord record) async {
    await database
        .into(database.studentRecords)
        .insertOnConflictUpdate(
          StudentRecordsCompanion(
            studentId: Value(record.studentId),
            strengths: Value(record.strengths),
            difficulties: Value(record.difficulties),
            supports: Value(record.supports),
          ),
        );
  }

  @override
  Future<List<StudentRecordEntry>> listEntries(String studentId) async {
    final rows =
        await (database.select(database.studentRecordEntries)
              ..where((table) => table.studentId.equals(studentId))
              ..orderBy([(table) => OrderingTerm.desc(table.occurredAt)]))
            .get();
    return List<StudentRecordEntry>.unmodifiable(
      rows.map(
        (row) => StudentRecordEntry(
          id: row.id,
          studentId: row.studentId,
          kind: row.kind,
          occurredAt: row.occurredAt,
          text: row.content,
        ),
      ),
    );
  }

  @override
  Future<void> addEntry(StudentRecordEntry entry) async {
    await database
        .into(database.studentRecordEntries)
        .insert(
          StudentRecordEntriesCompanion(
            id: Value(entry.id),
            studentId: Value(entry.studentId),
            kind: Value(entry.kind),
            occurredAt: Value(entry.occurredAt),
            content: Value(entry.text),
          ),
        );
  }
}
