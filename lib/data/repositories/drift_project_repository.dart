import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/sync_metadata_values.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:drift/drift.dart';

final class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(
    this.database, {
    SyncDeviceIdProvider? deviceIdProvider,
  }) : _deviceIdProvider = deviceIdProvider;

  final AppDatabase database;
  final SyncDeviceIdProvider? _deviceIdProvider;

  @override
  Future<Project?> findById(String id) async {
    final row =
        await (database.select(database.projects)
              ..where((table) => table.id.equals(id))
              ..where((table) => table.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Project>> listForGroup(String groupId) async {
    final rows =
        await (database.select(database.projects)
              ..where((table) => table.groupId.equals(groupId))
              ..where((table) => table.deletedAt.isNull())
              ..orderBy([(table) => OrderingTerm.asc(table.title)]))
            .get();
    final result = <Project>[];
    for (final row in rows) {
      result.add(await _toDomain(row));
    }
    return List<Project>.unmodifiable(result);
  }

  @override
  Future<void> save(Project project) async {
    final timestamp = SyncMetadataValues.now();
    final deviceId = await SyncMetadataValues.deviceId(_deviceIdProvider);
    await database.transaction(() async {
      await database
          .into(database.projects)
          .insertOnConflictUpdate(
            ProjectsCompanion(
              id: Value(project.id),
              groupId: Value(project.groupId),
              title: Value(project.title),
              description: Value(project.description),
              startsOn: Value(project.startsOn),
              endsOn: Value(project.endsOn),
              observations: Value(project.observations),
              lifecycle: Value(project.lifecycle),
              methodology: Value(project.methodology),
              formativeField: const Value(FormativeField.unspecified),
              deletedAt: const Value(null),
              updatedAt: SyncMetadataValues.updated(timestamp),
              updatedByDeviceId: deviceId,
            ),
          );
      await (database.update(
        database.projectGrades,
      )..where((table) => table.projectId.equals(project.id))).write(
        ProjectGradesCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await (database.update(
        database.projectFormativeFields,
      )..where((table) => table.projectId.equals(project.id))).write(
        ProjectFormativeFieldsCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await (database.update(
        database.projectArticulatingAxes,
      )..where((table) => table.projectId.equals(project.id))).write(
        ProjectArticulatingAxesCompanion(
          deletedAt: SyncMetadataValues.deleted(timestamp),
          updatedAt: SyncMetadataValues.updated(timestamp),
          updatedByDeviceId: deviceId,
        ),
      );
      await database.batch((batch) {
        for (final grade in project.targetGrades) {
          batch.insert(
            database.projectGrades,
            ProjectGradesCompanion(
              projectId: Value(project.id),
              grade: Value(grade),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              deletedAt: const Value(null),
              updatedByDeviceId: deviceId,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
        for (final axis in project.articulatingAxes) {
          batch.insert(
            database.projectArticulatingAxes,
            ProjectArticulatingAxesCompanion(
              projectId: Value(project.id),
              articulatingAxis: Value(axis),
              createdAt: SyncMetadataValues.created(timestamp),
              updatedAt: SyncMetadataValues.updated(timestamp),
              deletedAt: const Value(null),
              updatedByDeviceId: deviceId,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  Future<Project> _toDomain(ProjectRow row) async {
    final grades =
        await (database.select(database.projectGrades)..where(
              (table) =>
                  table.projectId.equals(row.id) & table.deletedAt.isNull(),
            ))
            .get();
    final axes =
        await (database.select(database.projectArticulatingAxes)..where(
              (table) =>
                  table.projectId.equals(row.id) & table.deletedAt.isNull(),
            ))
            .get();
    return Project(
      id: row.id,
      groupId: row.groupId,
      title: row.title,
      description: row.description,
      startsOn: row.startsOn,
      endsOn: row.endsOn,
      observations: row.observations,
      lifecycle: row.lifecycle,
      methodology: row.methodology,
      articulatingAxes: {for (final axis in axes) axis.articulatingAxis},
      targetGrades: {for (final grade in grades) grade.grade},
    );
  }
}
