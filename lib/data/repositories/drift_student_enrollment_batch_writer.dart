import 'package:aularaiz/application/contracts/student_enrollment_batch_writer.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:drift/drift.dart';

final class DriftStudentEnrollmentBatchWriter
    implements StudentEnrollmentBatchWriter {
  DriftStudentEnrollmentBatchWriter(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<void> saveBatch(List<NewStudentEnrollment> entries) async {
    if (entries.isEmpty) return;

    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      for (final entry in entries) {
        final student = entry.student;
        final enrollment = entry.enrollment;
        await database
            .into(database.students)
            .insert(
              StudentsCompanion(
                id: Value(student.id),
                givenNames: Value(student.givenNames),
                firstSurname: Value(student.firstSurname),
                secondSurname: Value(student.secondSurname),
                sex: Value(student.sex),
                birthDate: Value(student.birthDate),
                createdAt: SyncMetadataValues.created(timestamp),
                updatedAt: SyncMetadataValues.updated(timestamp),
                deletedAt: const Value(null),
                updatedByDeviceId: deviceId,
              ),
            );
        await database
            .into(database.enrollments)
            .insert(
              EnrollmentsCompanion(
                id: Value(enrollment.id),
                studentId: Value(enrollment.studentId),
                groupId: Value(enrollment.groupId),
                grade: Value(enrollment.grade),
                listNumber: Value(enrollment.listNumber),
                startsOn: Value(enrollment.startsOn),
                endsOn: Value(enrollment.endsOn),
                createdAt: SyncMetadataValues.created(timestamp),
                updatedAt: SyncMetadataValues.updated(timestamp),
                deletedAt: const Value(null),
                updatedByDeviceId: deviceId,
              ),
            );
      }
    });
  }
}
