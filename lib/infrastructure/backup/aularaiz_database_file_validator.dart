import 'dart:io';
import 'dart:isolate';

import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:sqlite3/sqlite3.dart';

final class DatabaseFileValidation {
  const DatabaseFileValidation({required this.schemaVersion});

  final int schemaVersion;
}

final class AulaRaizDatabaseFileValidator {
  const AulaRaizDatabaseFileValidator();

  static const Set<String> _requiredTables = <String>{
    'schools',
    'school_years',
    'teaching_groups',
    'students',
    'enrollments',
  };

  Future<DatabaseFileValidation> validate(
    File file, {
    required int maxSchemaVersion,
    int? exactSchemaVersion,
  }) async {
    if (!await file.exists()) {
      throw const RestoreException(
        RestoreProblem.missingRestoreArtifact,
        'Restore database file does not exist.',
      );
    }

    try {
      final result = await Isolate.run(
        () => _validatePath(
          file.path,
          maxSchemaVersion,
          exactSchemaVersion,
        ),
      );
      return DatabaseFileValidation(schemaVersion: result);
    } on RestoreException {
      rethrow;
    } on Object catch (error) {
      throw RestoreException(
        RestoreProblem.invalidDatabase,
        'Restore database could not be validated.',
        error,
      );
    }
  }

  static int _validatePath(
    String path,
    int maxSchemaVersion,
    int? exactSchemaVersion,
  ) {
    final database = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      final quickCheck = database.select('PRAGMA quick_check');
      final quickCheckValue = quickCheck.isEmpty
          ? null
          : quickCheck.first.values.firstOrNull;
      if (quickCheckValue != 'ok') {
        throw const RestoreException(
          RestoreProblem.invalidDatabase,
          'SQLite integrity check failed.',
        );
      }

      final versionRows = database.select('PRAGMA user_version');
      final versionValue = versionRows.isEmpty
          ? null
          : versionRows.first.values.firstOrNull;
      if (versionValue is! int || versionValue <= 0) {
        throw const RestoreException(
          RestoreProblem.invalidDatabase,
          'Restore database has no valid schema version.',
        );
      }
      if (versionValue > maxSchemaVersion) {
        throw RestoreException(
          RestoreProblem.newerSchema,
          'Restore database schema $versionValue is newer than supported schema $maxSchemaVersion.',
        );
      }
      if (exactSchemaVersion != null && versionValue != exactSchemaVersion) {
        throw RestoreException(
          RestoreProblem.invalidDatabase,
          'Restore database schema $versionValue did not migrate to $exactSchemaVersion.',
        );
      }

      final tableRows = database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );
      final tables = tableRows
          .map((row) => row['name'])
          .whereType<String>()
          .toSet();
      if (!tables.containsAll(_requiredTables)) {
        throw const RestoreException(
          RestoreProblem.invalidDatabase,
          'Restore database is missing required AulaRaíz tables.',
        );
      }

      return versionValue;
    } finally {
      database.dispose();
    }
  }
}
