import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:drift/drift.dart';

final class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this.database);

  final AppDatabase database;

  @override
  Future<Project?> findById(String id) async {
    final row =
        await (database.select(database.projects)
              ..where((table) => table.id.equals(id))
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Project>> listForGroup(String groupId) async {
    final rows =
        await (database.select(database.projects)
              ..where((table) => table.groupId.equals(groupId))
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
            ),
          );
      await (database.delete(
        database.projectGrades,
      )..where((table) => table.projectId.equals(project.id))).go();
      await (database.delete(
        database.projectFormativeFields,
      )..where((table) => table.projectId.equals(project.id))).go();
      await (database.delete(
        database.projectArticulatingAxes,
      )..where((table) => table.projectId.equals(project.id))).go();
      await database.batch((batch) {
        for (final grade in project.targetGrades) {
          batch.insert(
            database.projectGrades,
            ProjectGradesCompanion(
              projectId: Value(project.id),
              grade: Value(grade),
            ),
          );
        }
        for (final axis in project.articulatingAxes) {
          batch.insert(
            database.projectArticulatingAxes,
            ProjectArticulatingAxesCompanion(
              projectId: Value(project.id),
              articulatingAxis: Value(axis),
            ),
          );
        }
      });
    });
  }

  Future<Project> _toDomain(ProjectRow row) async {
    final grades = await (database.select(
      database.projectGrades,
    )..where((table) => table.projectId.equals(row.id))).get();
    final axes = await (database.select(
      database.projectArticulatingAxes,
    )..where((table) => table.projectId.equals(row.id))).get();
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
