import 'dart:io';

import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_layout.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/sync/sync_device_registry.dart';
import 'package:aularaiz/infrastructure/widgets/teacher_attendance_widget_action.dart';
import 'package:aularaiz/infrastructure/widgets/teacher_attendance_widget_service.dart';
import 'package:drift/drift.dart';
import 'package:home_widget/home_widget.dart';

/// Called by home_widget's background Flutter engine; it does not run the app UI.
@pragma('vm:entry-point')
Future<void> teacherAttendanceWidgetCallback(Uri? uri) async {
  if (!Platform.isAndroid ||
      uri?.scheme != 'aularaiz' ||
      uri?.host != 'teacher-attendance') {
    return;
  }
  final schoolId = uri!.queryParameters['schoolId'];
  final action = uri.queryParameters['action'];
  final date = uri.queryParameters['date'];
  final profileName = uri.queryParameters['profile'];
  if (schoolId == null ||
      schoolId.isEmpty ||
      date == null ||
      !const {'arrival', 'departure'}.contains(action) ||
      !StorageProfile.values.any((profile) => profile.name == profileName)) {
    return;
  }

  AppDatabase? database;
  var actionSaved = false;
  try {
    final profile = StorageProfile.values.singleWhere(
      (value) => value.name == profileName,
    );
    final layout = await AulaRaizStorageLayout.resolve(profile);
    // Do not create an empty database or write while a restore is pending.
    if (!await layout.databaseFile.exists() ||
        await layout.restoreMarkerFile.exists()) {
      await _showFailure(
        'Abre AulaRaíz para revisar tus datos antes de registrar.',
      );
      return;
    }
    database = switch (profile) {
      StorageProfile.production => AppDatabase.production(),
      StorageProfile.demo => AppDatabase.demo(),
    };
    await database.customStatement('PRAGMA busy_timeout = 5000');
    final registry = SyncDeviceRegistry();
    final writer = TeacherAttendanceWidgetAction(
      database,
      deviceIdProvider: () async => (await registry.identity()).id,
    );
    final result = await writer.apply(
      schoolId: schoolId,
      action: action!,
      expectedDate: date,
    );
    actionSaved = result == TeacherWidgetActionResult.saved;
    if (result == TeacherWidgetActionResult.unavailable) {
      await _showFailure(
        'La escuela ya no está disponible. Toca el nombre para revisar.',
      );
      return;
    }

    // A school may have been changed while this tap was queued. Refresh only
    // the current widget selection using its current database profile.
    final currentSchoolId = await HomeWidget.getWidgetData<String>(
      'teacher_attendance_school_id',
    );
    final currentProfile = await HomeWidget.getWidgetData<String>(
      'teacher_attendance_profile',
    );
    if (currentSchoolId != schoolId ||
        (currentProfile ?? StorageProfile.production.name) != profile.name) {
      return;
    }
    final school =
        await (database.select(database.schools)..where(
              (table) => table.id.equals(schoolId) & table.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (school != null) {
      await TeacherAttendanceWidgetService.refresh(
        schoolId: school.id,
        schoolName: school.name,
        repository: writer.repository,
      );
    }
  } catch (error) {
    await SafeLog.initialize();
    SafeLog.operationFailure('teacher_attendance_widget_action', error);
    await _showFailure(
      actionSaved
          ? 'Registro guardado. Abre AulaRaíz para actualizar la vista.'
          : 'No se pudo guardar. Inténtalo de nuevo o abre AulaRaíz.',
    );
  } finally {
    await database?.close();
  }
}

Future<void> _showFailure(String message) async {
  await HomeWidget.saveWidgetData<String>('teacher_attendance_status', message);
  final now = DateTime.now();
  await HomeWidget.saveWidgetData<String>(
    'teacher_attendance_date',
    '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}',
  );
  await HomeWidget.updateWidget(
    qualifiedAndroidName:
        'com.mindtzijib.aularaiz.TeacherAttendanceWidgetProvider',
  );
}
