import 'dart:io';

import 'package:aularaiz/application/contracts/teacher_attendance_repository.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/data/repositories/drift_teacher_attendance_repository.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_record.dart';
import 'package:home_widget/home_widget.dart';

final class TeacherAttendanceWidgetService {
  const TeacherAttendanceWidgetService._();

  static Future<void> refresh({
    required String schoolId,
    required String schoolName,
    required TeacherAttendanceRepository repository,
  }) async {
    if (!Platform.isAndroid) return;

    final record = await repository.findForDate(schoolId, DateTime.now());
    final snapshot = _snapshot(record);
    final now = DateTime.now();
    final profile = repository is DriftTeacherAttendanceRepository
        ? repository.database.storageProfile ?? StorageProfile.production
        : StorageProfile.production;
    await HomeWidget.saveWidgetData<String>(
      'teacher_attendance_profile',
      profile.name,
    );
    await HomeWidget.saveWidgetData<String>(
      'teacher_attendance_school_id',
      schoolId,
    );
    await HomeWidget.saveWidgetData<String>(
      'teacher_attendance_school_name',
      schoolName,
    );
    await HomeWidget.saveWidgetData<String>(
      'teacher_attendance_status',
      snapshot.status,
    );
    await HomeWidget.saveWidgetData<String>(
      'teacher_attendance_action',
      snapshot.action,
    );
    await HomeWidget.saveWidgetData<String>(
      'teacher_attendance_action_label',
      snapshot.actionLabel,
    );
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

  static _TeacherAttendanceWidgetSnapshot _snapshot(
    TeacherAttendanceRecord? record,
  ) {
    if (record == null) {
      return const _TeacherAttendanceWidgetSnapshot(
        status: 'Entrada pendiente',
        action: 'arrival',
        actionLabel: 'Registrar entrada',
      );
    }
    final arrival = _time(record.arrivedAt);
    final departure = record.departedAt;
    if (departure == null) {
      return _TeacherAttendanceWidgetSnapshot(
        status: 'Entrada registrada · $arrival',
        action: 'departure',
        actionLabel: 'Registrar salida',
      );
    }
    return _TeacherAttendanceWidgetSnapshot(
      status: 'Jornada completa · $arrival–${_time(departure)}',
      action: 'open',
      actionLabel: 'Ver jornada',
    );
  }

  static String _time(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

final class _TeacherAttendanceWidgetSnapshot {
  const _TeacherAttendanceWidgetSnapshot({
    required this.status,
    required this.action,
    required this.actionLabel,
  });

  final String status;
  final String action;
  final String actionLabel;
}
