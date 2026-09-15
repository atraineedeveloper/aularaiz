import 'dart:io';

import 'package:aularaiz/application/backup/aularaiz_backup_codec.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/application/contracts/backup_protector.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_layout.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/aularaiz_database_file_validator.dart';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

final class RecordLevelSyncSummary {
  const RecordLevelSyncSummary({
    required this.inserted,
    required this.updated,
    required this.skipped,
  });

  final int inserted;
  final int updated;
  final int skipped;

  int get changed => inserted + updated;
}

final class RecordLevelSyncService {
  RecordLevelSyncService({
    required AppDatabase database,
    required StorageProfile profile,
    required int currentSchemaVersion,
    ApplicationSupportDirectoryProvider directoryProvider =
        getApplicationSupportDirectory,
    AulaRaizBackupCodec codec = const AulaRaizBackupCodec(),
    AulaRaizDatabaseFileValidator validator =
        const AulaRaizDatabaseFileValidator(),
  }) : _database = database,
       _profile = profile,
       _currentSchemaVersion = currentSchemaVersion,
       _directoryProvider = directoryProvider,
       _codec = codec,
       _validator = validator;

  final AppDatabase _database;
  final StorageProfile _profile;
  final int _currentSchemaVersion;
  final ApplicationSupportDirectoryProvider _directoryProvider;
  final AulaRaizBackupCodec _codec;
  final AulaRaizDatabaseFileValidator _validator;

  static const List<String> _syncTables = <String>[
    'schools',
    'school_years',
    'school_contexts',
    'teaching_groups',
    'group_grades',
    'students',
    'enrollments',
    'attendance_days',
    'attendance_entries',
    'projects',
    'project_grades',
    'project_formative_fields',
    'project_articulating_axes',
    'activities',
    'activity_grades',
    'activity_formative_fields',
    'activity_roster',
    'activity_evaluations',
    'student_records',
    'student_record_entries',
    'literacy_assessments',
    'teacher_profiles',
  ];

  Future<RecordLevelSyncSummary> mergeBackup({
    required Uint8List backupBytes,
    required BackupProtector protector,
  }) async {
    final clearBackupBytes = await protector.unprotect(backupBytes);
    final inspection = _codec.inspect(clearBackupBytes);
    _validateManifest(inspection.manifest);

    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    final incoming = File(
      '${directory.path}${Platform.pathSeparator}'
      'aularaiz-sync-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    try {
      await incoming.writeAsBytes(inspection.databaseBytes, flush: true);
      await _validator.validate(
        incoming,
        maxSchemaVersion: _currentSchemaVersion,
        exactSchemaVersion: inspection.manifest.schemaVersion,
      );
      return await mergeDatabaseFile(incoming);
    } finally {
      if (await incoming.exists()) await incoming.delete();
    }
  }

  Future<RecordLevelSyncSummary> mergeDatabaseFile(File incomingFile) async {
    var inserted = 0;
    var updated = 0;
    var skipped = 0;
    var attached = false;

    await _database.customStatement('ATTACH DATABASE ? AS incoming', [
      incomingFile.path,
    ]);
    attached = true;
    try {
      await _database.transaction(() async {
        for (final table in _syncTables) {
          final tableResult = await _mergeTable(table);
          inserted += tableResult.inserted;
          updated += tableResult.updated;
          skipped += tableResult.skipped;
        }
      });
    } finally {
      if (attached) {
        await _database.customStatement('DETACH DATABASE incoming');
        attached = false;
      }
    }

    return RecordLevelSyncSummary(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
    );
  }

  Future<RecordLevelSyncSummary> _mergeTable(String table) async {
    final localColumns = await _columns('main', table);
    final incomingColumns = await _columns('incoming', table);
    if (localColumns.isEmpty || incomingColumns.isEmpty) {
      return const RecordLevelSyncSummary(inserted: 0, updated: 0, skipped: 0);
    }

    final localByName = {
      for (final column in localColumns) column.name: column,
    };
    final incomingNames = incomingColumns.map((column) => column.name).toSet();
    final commonColumns = localColumns
        .map((column) => column.name)
        .where(incomingNames.contains)
        .toList(growable: false);
    final primaryKey =
        localColumns
            .where((column) => column.primaryKeyOrder > 0)
            .toList(growable: false)
          ..sort(
            (left, right) =>
                left.primaryKeyOrder.compareTo(right.primaryKeyOrder),
          );
    if (primaryKey.isEmpty || commonColumns.isEmpty) {
      return RecordLevelSyncSummary(
        inserted: 0,
        updated: 0,
        skipped: incomingColumns.isEmpty ? 0 : 1,
      );
    }

    final rows = await _database
        .customSelect(
          'SELECT ${_columnList(commonColumns)} FROM incoming.${_q(table)}',
        )
        .get();
    var inserted = 0;
    var updated = 0;
    var skipped = 0;

    for (final row in rows) {
      final data = row.data;
      final incomingDeletedAt = _asTimestamp(data['deleted_at']);
      final where = _where(primaryKey.map((column) => column.name));
      final pkValues = primaryKey.map((column) => data[column.name]).toList();
      final existing = await _database
          .customSelect(
            'SELECT ${_columnList(commonColumns)} FROM main.${_q(table)} '
            'WHERE $where LIMIT 1',
            variables: pkValues.map((value) => Variable(value)).toList(),
          )
          .getSingleOrNull();

      if (existing == null) {
        if (incomingDeletedAt != null) {
          skipped++;
          continue;
        }
        final changed = await _insertRow(table, commonColumns, data);
        if (changed) {
          inserted++;
        } else {
          skipped++;
        }
        continue;
      }

      final incomingUpdatedAt = _asTimestamp(data['updated_at']);
      final existingUpdatedAt = _asTimestamp(existing.data['updated_at']);
      if (incomingDeletedAt != null) {
        if (!_incomingWins(incomingDeletedAt, existingUpdatedAt)) {
          skipped++;
          continue;
        }
        final changed = await _database.customUpdate(
          'UPDATE main.${_q(table)} '
          'SET deleted_at = ?, updated_at = ?, updated_by_device_id = ? '
          'WHERE $where',
          variables: [
            Variable(data['deleted_at']),
            Variable(data['updated_at'] ?? data['deleted_at']),
            Variable(data['updated_by_device_id']),
            for (final value in pkValues) Variable(value),
          ],
        );
        if (changed > 0) {
          updated++;
        } else {
          skipped++;
        }
        continue;
      }
      if (!_incomingWins(incomingUpdatedAt, existingUpdatedAt)) {
        skipped++;
        continue;
      }

      final updateColumns = commonColumns
          .where((name) => !primaryKey.any((pk) => pk.name == name))
          .where(localByName.containsKey)
          .toList(growable: false);
      if (updateColumns.isEmpty) {
        skipped++;
        continue;
      }
      final setClause = updateColumns
          .map((name) => '${_q(name)} = ?')
          .join(', ');
      final changed = await _database.customUpdate(
        'UPDATE main.${_q(table)} SET $setClause WHERE $where',
        variables: [
          for (final column in updateColumns) Variable(data[column]),
          for (final value in pkValues) Variable(value),
        ],
      );
      if (changed > 0) {
        updated++;
      } else {
        skipped++;
      }
    }

    return RecordLevelSyncSummary(
      inserted: inserted,
      updated: updated,
      skipped: skipped,
    );
  }

  Future<List<_ColumnInfo>> _columns(String schema, String table) async {
    final rows = await _database
        .customSelect('PRAGMA $schema.table_info(${_stringLiteral(table)})')
        .get();
    return [
      for (final row in rows)
        _ColumnInfo(
          name: row.read<String>('name'),
          primaryKeyOrder: row.read<int>('pk'),
        ),
    ];
  }

  Future<bool> _insertRow(
    String table,
    List<String> columns,
    Map<String, Object?> data,
  ) async {
    final placeholders = List.filled(columns.length, '?').join(', ');
    final before = await _totalChanges();
    await _database.customStatement(
      'INSERT OR IGNORE INTO main.${_q(table)} '
      '(${_columnList(columns)}) VALUES ($placeholders)',
      [for (final column in columns) data[column]],
    );
    final after = await _totalChanges();
    return after > before;
  }

  Future<int> _totalChanges() async {
    final row = await _database
        .customSelect('SELECT total_changes() AS n')
        .getSingle();
    return row.read<int>('n');
  }

  bool _incomingWins(int? incomingUpdatedAt, int? existingUpdatedAt) {
    if (incomingUpdatedAt == null) return false;
    if (existingUpdatedAt == null) return true;
    return incomingUpdatedAt > existingUpdatedAt;
  }

  int? _asTimestamp(Object? value) {
    if (value is int) return value;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return null;
  }

  String _where(Iterable<String> columns) =>
      columns.map((name) => '${_q(name)} = ?').join(' AND ');

  String _columnList(Iterable<String> columns) => columns.map(_q).join(', ');

  String _q(String identifier) => '"${identifier.replaceAll('"', '""')}"';

  String _stringLiteral(String value) => "'${value.replaceAll("'", "''")}'";

  void _validateManifest(BackupManifest manifest) {
    if (manifest.storageProfile != _profile.name) {
      throw RestoreException(
        RestoreProblem.profileMismatch,
        'Backup profile ${manifest.storageProfile} cannot sync ${_profile.name}.',
      );
    }
    if (manifest.schemaVersion > _currentSchemaVersion) {
      throw RestoreException(
        RestoreProblem.newerSchema,
        'Backup schema ${manifest.schemaVersion} is newer than supported schema $_currentSchemaVersion.',
      );
    }
  }
}

final class _ColumnInfo {
  const _ColumnInfo({required this.name, required this.primaryKeyOrder});

  final String name;
  final int primaryKeyOrder;
}
