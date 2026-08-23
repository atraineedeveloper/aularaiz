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
    final legacyField = _legacyField(project.formativeFields);
    await database.transaction(() async {
      await database
          .into(database.projects)
          .insertOnConflictUpdate(
            ProjectsCompanion(
              id: Value(project.id),
              groupId: Value(project.groupId),
              title: Value(project.title),
              lifecycle: Value(project.lifecycle),
              methodology: Value(project.methodology),
              formativeField: Value(legacyField),
            ),
          );
      await (database.delete(
        database.projectGrades,
      )..where((table) => table.projectId.equals(project.id))).go();
      await (database.delete(database.projectFormativeFields)
            ..where((table) => table.projectId.equals(project.id)))
          .go();
      await (database.delete(database.projectArticulatingAxes)
            ..where((table) => table.projectId.equals(project.id)))
          .go();
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
        for (final field in project.formativeFields) {
          batch.insert(
            database.projectFormativeFields,
            ProjectFormativeFieldsCompanion(
              projectId: Value(project.id),
              formativeField: Value(field),
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
    final fieldRows = await (database.select(
      database.projectFormativeFields,
    )..where((table) => table.projectId.equals(row.id))).get();
    final axisRows = await (database.select(
      database.projectArticulatingAxes,
    )..where((table) => table.projectId.equals(row.id))).get();
    final fields = fieldRows.isEmpty
        ? <FormativeField>{row.formativeField}
        : <FormativeField>{for (final field in fieldRows) field.formativeField};
    return Project(
      id: row.id,
      groupId: row.groupId,
      title: row.title,
      lifecycle: row.lifecycle,
      methodology: row.methodology,
      formativeFields: fields,
      articulatingAxes: {
        for (final axis in axisRows) axis.articulatingAxis,
      },
      targetGrades: {for (final grade in grades) grade.grade},
    );
  }

  FormativeField _legacyField(Set<FormativeField> fields) {
    final values = fields.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    return values.first;
  }
}
