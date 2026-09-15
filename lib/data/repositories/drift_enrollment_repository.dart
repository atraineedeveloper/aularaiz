import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:drift/drift.dart';

final class DriftEnrollmentRepository implements EnrollmentRepository {
  DriftEnrollmentRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async {
    final rows =
        await (database.select(database.enrollments)..where(
              (table) =>
                  table.studentId.equals(studentId) & table.deletedAt.isNull(),
            ))
            .get();

    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async {
    final rows =
        await (database.select(database.enrollments)..where(
              (table) =>
                  table.groupId.equals(groupId) & table.deletedAt.isNull(),
            ))
            .get();

    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> save(Enrollment enrollment) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database
        .into(database.enrollments)
        .insertOnConflictUpdate(
          EnrollmentsCompanion(
            id: Value(enrollment.id),
            studentId: Value(enrollment.studentId),
            groupId: Value(enrollment.groupId),
            grade: Value(enrollment.grade),
            listNumber: Value(enrollment.listNumber),
            startsOn: Value(enrollment.startsOn),
            endsOn: Value(enrollment.endsOn),
            deletedAt: const Value(null),
            updatedAt: SyncMetadataValues.updated(timestamp),
            updatedByDeviceId: deviceId,
          ),
        );
  }

  Enrollment _toDomain(EnrollmentRow row) {
    return Enrollment(
      id: row.id,
      studentId: row.studentId,
      groupId: row.groupId,
      grade: row.grade,
      listNumber: row.listNumber,
      startsOn: row.startsOn,
      endsOn: row.endsOn,
    );
  }
}
