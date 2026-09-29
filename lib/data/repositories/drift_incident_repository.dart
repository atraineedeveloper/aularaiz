import 'package:aularaiz/application/contracts/incident_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/incident/incident_report.dart';
import 'package:drift/drift.dart';

final class DriftIncidentRepository implements IncidentRepository {
  DriftIncidentRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<List<IncidentReport>> listForSchool(String schoolId) async {
    final rows =
        await (database.select(database.incidentReports)
              ..where(
                (table) =>
                    table.schoolId.equals(schoolId) & table.deletedAt.isNull(),
              )
              ..orderBy([
                (table) => OrderingTerm.desc(table.occurredAt),
                (table) => OrderingTerm.desc(table.createdAt),
              ]))
            .get();
    return _withParticipants(rows);
  }

  @override
  Future<List<IncidentReport>> listForStudent(String studentId) async {
    final links =
        await (database.select(database.incidentParticipants)..where(
              (table) =>
                  table.studentId.equals(studentId) & table.deletedAt.isNull(),
            ))
            .get();
    if (links.isEmpty) return const <IncidentReport>[];
    final reportIds = links.map((link) => link.incidentId).toSet().toList();
    final rows =
        await (database.select(database.incidentReports)
              ..where(
                (table) => table.id.isIn(reportIds) & table.deletedAt.isNull(),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.occurredAt)]))
            .get();
    return _withParticipants(rows);
  }

  Future<List<IncidentReport>> _withParticipants(
    List<IncidentReportRow> rows,
  ) async {
    if (rows.isEmpty) return const <IncidentReport>[];
    final ids = rows.map((row) => row.id).toList(growable: false);
    final links =
        await (database.select(database.incidentParticipants)..where(
              (table) => table.incidentId.isIn(ids) & table.deletedAt.isNull(),
            ))
            .get();
    final participants = <String, List<String>>{};
    for (final link in links) {
      participants
          .putIfAbsent(link.incidentId, () => <String>[])
          .add(link.studentId);
    }
    return List<IncidentReport>.unmodifiable(
      rows.map((row) => _toDomain(row, participants[row.id] ?? const [])),
    );
  }

  @override
  Future<void> save(IncidentReport report) async {
    final now = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      final existing =
          await (database.select(database.incidentReports)
                ..where((table) => table.id.equals(report.id))
                ..limit(1))
              .getSingleOrNull();
      final values = IncidentReportsCompanion(
        id: Value(report.id),
        schoolId: Value(report.schoolId),
        groupId: Value(report.groupId),
        occurredAt: Value(report.occurredAt),
        category: Value(report.category),
        description: Value(report.description),
        actionTaken: Value(report.actionTaken),
        followUpNote: Value(report.followUpNote),
        familyNotified: Value(report.familyNotified),
        leadershipNotified: Value(report.leadershipNotified),
        status: Value(report.status),
        correctedAt: Value(report.correctedAt?.toUtc()),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        updatedByDeviceId: deviceId,
      );
      if (existing == null) {
        await database
            .into(database.incidentReports)
            .insert(values.copyWith(createdAt: Value(now)));
      } else {
        await (database.update(
          database.incidentReports,
        )..where((table) => table.id.equals(report.id))).write(values);
      }

      final existingLinks = await (database.select(
        database.incidentParticipants,
      )..where((table) => table.incidentId.equals(report.id))).get();
      final selectedIds = report.studentIds.toSet();
      for (final link in existingLinks) {
        if (selectedIds.contains(link.studentId) || link.deletedAt != null) {
          continue;
        }
        await (database.update(database.incidentParticipants)..where(
              (table) =>
                  table.incidentId.equals(report.id) &
                  table.studentId.equals(link.studentId),
            ))
            .write(
              IncidentParticipantsCompanion(
                deletedAt: Value(now),
                updatedAt: Value(now),
                updatedByDeviceId: deviceId,
              ),
            );
      }

      final linksByStudent = {
        for (final link in existingLinks) link.studentId: link,
      };
      for (final studentId in selectedIds) {
        final existingLink = linksByStudent[studentId];
        if (existingLink == null) {
          await database
              .into(database.incidentParticipants)
              .insert(
                IncidentParticipantsCompanion.insert(
                  incidentId: report.id,
                  studentId: studentId,
                  createdAt: Value(now),
                  updatedAt: Value(now),
                  updatedByDeviceId: deviceId,
                ),
              );
        } else {
          await (database.update(database.incidentParticipants)..where(
                (table) =>
                    table.incidentId.equals(report.id) &
                    table.studentId.equals(studentId),
              ))
              .write(
                IncidentParticipantsCompanion(
                  deletedAt: const Value(null),
                  updatedAt: Value(now),
                  updatedByDeviceId: deviceId,
                ),
              );
        }
      }
    });
  }

  IncidentReport _toDomain(IncidentReportRow row, List<String> studentIds) =>
      IncidentReport(
        id: row.id,
        schoolId: row.schoolId,
        groupId: row.groupId,
        occurredAt: row.occurredAt.toLocal(),
        category: row.category,
        description: row.description,
        actionTaken: row.actionTaken,
        followUpNote: row.followUpNote,
        familyNotified: row.familyNotified,
        leadershipNotified: row.leadershipNotified,
        status: row.status,
        studentIds: studentIds,
        correctedAt: row.correctedAt?.toLocal(),
      );
}
