import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aularaiz/app/errors/friendly_error_message.dart';
import 'package:aularaiz/app/layout/responsive_layout.dart';
import 'package:aularaiz/application/contracts/teacher_attendance_repository.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_record.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_schedule.dart';
import 'package:aularaiz/features/teacher_attendance/presentation/teacher_attendance_controller.dart';
import 'package:aularaiz/infrastructure/reports/report_publication_service.dart';
import 'package:aularaiz/infrastructure/widgets/teacher_attendance_widget_service.dart';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({
    required this.schoolId,
    required this.schoolName,
    this.embedded = false,
    this.initialQuickAction,
    super.key,
  });

  final String schoolId;
  final String schoolName;
  final bool embedded;
  final String? initialQuickAction;

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen>
    with WidgetsBindingObserver {
  bool _loadStarted = false;
  bool _quickActionHandled = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAfterBackgroundAction());
    }
  }

  Future<void> _refreshAfterBackgroundAction() async {
    if (!mounted || !_loadStarted) return;
    final controller = context.read<TeacherAttendanceController>();
    if (controller.isLoading || controller.isSaving) return;
    await controller.refreshAfterSync();
    if (mounted) await _refreshWidget();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadAndRefresh());
      }
    });
  }

  Future<void> _loadAndRefresh() async {
    final controller = context.read<TeacherAttendanceController>();
    await controller.load(widget.schoolId);
    if (!mounted) return;
    await _refreshWidget();
    if (!mounted || _quickActionHandled) return;
    _quickActionHandled = true;
    final action = widget.initialQuickAction;
    if (action == 'arrival') {
      await _confirmWidgetArrival(controller);
    } else if (action == 'departure') {
      await _confirmWidgetDeparture(controller);
    }
  }

  Future<void> _confirmWidgetArrival(
    TeacherAttendanceController controller,
  ) async {
    if (controller.error != null) return;
    if (controller.todayRecord != null) {
      _showWidgetMessage(
        _t(
          context,
          'La entrada de hoy ya está registrada.',
          'Today’s arrival is already recorded.',
        ),
      );
      return;
    }
    final now = DateTime.now();
    final confirmed = await _confirmWidgetAction(
      title: _t(context, 'Registrar entrada', 'Record arrival'),
      message: _t(
        context,
        '¿Registrar tu entrada a las ${_time(context, now)} en ${widget.schoolName}?',
        'Record your arrival at ${_time(context, now)} at ${widget.schoolName}?',
      ),
    );
    if (!confirmed || !mounted) return;
    final saved = await controller.registerArrival();
    await _refreshWidget();
    if (!mounted) return;
    _showWidgetMessage(
      saved
          ? _t(context, 'Entrada registrada.', 'Arrival recorded.')
          : _t(
              context,
              'No se pudo registrar la entrada.',
              'Could not record arrival.',
            ),
    );
  }

  Future<void> _confirmWidgetDeparture(
    TeacherAttendanceController controller,
  ) async {
    if (controller.error != null) return;
    final record = controller.todayRecord;
    if (record == null || !record.isOpen) {
      _showWidgetMessage(
        _t(
          context,
          'No hay una jornada abierta para registrar salida.',
          'There is no open workday to record a departure.',
        ),
      );
      return;
    }
    final now = DateTime.now();
    final confirmed = await _confirmWidgetAction(
      title: _t(context, 'Registrar salida', 'Record departure'),
      message: _t(
        context,
        '¿Registrar tu salida a las ${_time(context, now)} de ${widget.schoolName}?',
        'Record your departure at ${_time(context, now)} from ${widget.schoolName}?',
      ),
    );
    if (!confirmed || !mounted) return;
    final saved = await controller.registerDeparture();
    await _refreshWidget();
    if (!mounted) return;
    _showWidgetMessage(
      saved
          ? _t(context, 'Salida registrada.', 'Departure recorded.')
          : _t(
              context,
              'No se pudo registrar la salida.',
              'Could not record departure.',
            ),
    );
  }

  Future<bool> _confirmWidgetAction({
    required String title,
    required String message,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(_t(context, 'Cancelar', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_t(context, 'Confirmar', 'Confirm')),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _refreshWidget() async {
    try {
      await TeacherAttendanceWidgetService.refresh(
        schoolId: widget.schoolId,
        schoolName: widget.schoolName,
        repository: context.read<TeacherAttendanceRepository>(),
      );
    } catch (_) {
      // Optional widget refresh must not block attendance registration.
    }
  }

  void _showWidgetMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _registerArrival() async {
    final saved = await context
        .read<TeacherAttendanceController>()
        .registerArrival();
    if (saved) await _refreshWidget();
    return saved;
  }

  Future<bool> _registerDeparture() async {
    final saved = await context
        .read<TeacherAttendanceController>()
        .registerDeparture();
    if (saved) await _refreshWidget();
    return saved;
  }

  Future<void> _pinWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        qualifiedAndroidName:
            'com.mindtzijib.aularaiz.TeacherAttendanceWidgetProvider',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'No se pudo agregar desde este launcher. Busca AulaRaíz en la lista de widgets de Android.',
              'This launcher could not add it. Find AulaRaíz in Android’s widget picker.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TeacherAttendanceController>();
    final layout = ResponsiveLayoutInfo.of(context);
    final record = controller.todayRecord;
    final localizations = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                _t(context, 'Asistencia del docente', 'Teacher attendance'),
              ),
            ),
      body: SafeArea(
        top: !widget.embedded,
        child: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.error != null && controller.records.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(layout.pagePadding),
                  child: Text(
                    friendlyErrorMessage(
                      context,
                      controller.error,
                      fallback: _t(
                        context,
                        'No se pudo cargar el historial.',
                        'The history could not be loaded.',
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: EdgeInsets.all(layout.pagePadding),
                    children: [
                      Text(
                        _t(
                          context,
                          'Asistencia del docente',
                          'Teacher attendance',
                        ),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.schoolName,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (Platform.isAndroid) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _pinWidget,
                            icon: const Icon(Icons.widgets_outlined),
                            label: Text(
                              _t(
                                context,
                                'Agregar widget a inicio',
                                'Add home screen widget',
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _TodayCard(
                        record: record,
                        isLate: record != null && controller.isLate(record),
                        leftEarly:
                            record?.departedAt != null &&
                            controller.isIncomplete(record!),
                        isSaving: controller.isSaving,
                        schoolName: widget.schoolName,
                        onArrival: _registerArrival,
                        onDeparture: _registerDeparture,
                      ),
                      const SizedBox(height: 12),
                      _ScheduleCard(
                        schedule: controller.schedule,
                        onConfigure: () =>
                            _configureSchedule(context, controller),
                      ),
                      if (controller.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          friendlyErrorMessage(
                            context,
                            controller.error,
                            fallback: _t(
                              context,
                              'No se pudo guardar el registro.',
                              'The attendance record could not be saved.',
                            ),
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _MonthlyReportCard(
                        month: controller.selectedMonth,
                        recordCount: controller.monthRecords.length,
                        lateCount: controller.lateCount,
                        incompleteCount: controller.incompleteCount,
                        totalWorked: controller.totalWorked,
                        onPrevious: controller.previousMonth,
                        onNext: controller.nextMonth,
                        onExport: () => _exportMonth(context, controller),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            _t(context, 'Historial', 'History'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TextButton.icon(
                            onPressed: controller.isSaving
                                ? null
                                : () => _addPastRecord(context, controller),
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              _t(context, 'Día anterior', 'Past day'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (controller.records.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _t(
                                context,
                                'Aún no hay jornadas registradas.',
                                'No workdays have been recorded yet.',
                              ),
                            ),
                          ),
                        )
                      else
                        for (final item in controller.records)
                          Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.event_available_outlined),
                              ),
                              title: Text(
                                localizations.formatMediumDate(
                                  item.attendanceDate,
                                ),
                              ),
                              subtitle: Text(
                                _recordSummary(context, item, controller),
                              ),
                              isThreeLine:
                                  item.notes != null ||
                                  item.wasCorrected ||
                                  item.isOpen ||
                                  controller.isLate(item) ||
                                  controller.isIncomplete(item),
                              trailing: IconButton(
                                tooltip: _t(
                                  context,
                                  'Corregir registro',
                                  'Correct record',
                                ),
                                onPressed: controller.isSaving
                                    ? null
                                    : () => _editRecord(
                                        context,
                                        controller,
                                        item,
                                      ),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _editRecord(
    BuildContext context,
    TeacherAttendanceController controller,
    TeacherAttendanceRecord record,
  ) async {
    final draft = await showDialog<_AttendanceCorrection>(
      context: context,
      builder: (context) => _CorrectionDialog(record: record),
    );
    if (draft == null || !context.mounted) return;
    final saved = await controller.correctRecord(
      record: record,
      arrivedAt: draft.arrivedAt,
      departedAt: draft.departedAt,
      notes: draft.notes,
    );
    if (!context.mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t(context, 'Registro actualizado.', 'Record updated.')),
      ),
    );
  }

  Future<void> _addPastRecord(
    BuildContext context,
    TeacherAttendanceController controller,
  ) async {
    final draft = await showDialog<_AttendanceCorrection>(
      context: context,
      builder: (context) => const _PastRecordDialog(),
    );
    if (draft == null || !context.mounted) return;
    final saved = await controller.addPastRecord(
      date: draft.date!,
      arrivedAt: draft.arrivedAt,
      departedAt: draft.departedAt,
      notes: draft.notes,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? _t(
                  context,
                  'Día agregado al historial.',
                  'Day added to history.',
                )
              : _t(
                  context,
                  'Ya existe un registro para ese día.',
                  'A record already exists for that day.',
                ),
        ),
      ),
    );
  }

  Future<void> _configureSchedule(
    BuildContext context,
    TeacherAttendanceController controller,
  ) async {
    final current = controller.schedule;
    final draft = await showDialog<_ScheduleDraft>(
      context: context,
      builder: (context) => _ScheduleDialog(schedule: current),
    );
    if (draft == null || !context.mounted) return;
    final saved = await controller.saveSchedule(
      expectedArrivalMinute: draft.enabled ? draft.arrivalMinute : null,
      expectedDepartureMinute: draft.enabled ? draft.departureMinute : null,
      arrivalGraceMinutes: draft.graceMinutes,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? _t(context, 'Horario guardado.', 'Schedule saved.')
              : _t(
                  context,
                  'No se pudo guardar el horario.',
                  'Could not save the schedule.',
                ),
        ),
      ),
    );
  }

  Future<void> _exportMonth(
    BuildContext context,
    TeacherAttendanceController controller,
  ) async {
    final rows = <List<Object?>>[
      [
        _t(context, 'Fecha', 'Date'),
        _t(context, 'Entrada', 'Arrival'),
        _t(context, 'Salida', 'Departure'),
        _t(context, 'Estado', 'Status'),
        _t(context, 'Nota', 'Note'),
      ],
      for (final record in controller.monthRecords)
        [
          _dateKey(record.attendanceDate),
          _time(context, record.arrivedAt),
          record.departedAt == null ? '' : _time(context, record.departedAt!),
          [
            if (controller.isLate(record)) _t(context, 'Retardo', 'Late'),
            if (record.isOpen)
              _t(context, 'Jornada abierta', 'Workday open')
            else if (controller.isIncomplete(record))
              _t(context, 'Jornada incompleta', 'Incomplete workday'),
            if (!record.isOpen &&
                !controller.isLate(record) &&
                !controller.isIncomplete(record))
              _t(context, 'Completa', 'Complete'),
          ].join('; '),
          record.notes ?? '',
        ],
    ];
    final csv =
        const CsvEncoder(
          fieldDelimiter: ',',
          lineDelimiter: '\r\n',
          addBom: true,
        ).convert(
          rows
              .map(
                (row) => row
                    .map<Object?>(
                      (value) => value is String ? _csvSafe(value) : value,
                    )
                    .toList(growable: false),
              )
              .toList(growable: false),
        );
    final month = controller.selectedMonth;
    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    try {
      await context.read<ReportPublicationService>().publishFile(
        bytes: Uint8List.fromList(utf8.encode(csv)),
        fileName: 'aularaiz-asistencia-docente-$monthKey.csv',
        mimeType: 'text/csv',
        extension: 'csv',
        typeLabel: 'CSV',
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              context,
              'No se pudo exportar el reporte.',
              'Could not export the report.',
            ),
          ),
        ),
      );
    }
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule, required this.onConfigure});

  final TeacherAttendanceSchedule? schedule;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final configured = schedule?.isConfigured ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: LayoutBuilder(
          builder: (context, constraints) => Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              SizedBox(
                width: constraints.maxWidth < 440 ? constraints.maxWidth : 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(context, 'Horario esperado', 'Expected schedule'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      configured
                          ? '${_t(context, 'Entrada', 'Arrival')} ${_minuteTime(context, schedule!.expectedArrivalMinute!)} · ${_t(context, 'Salida', 'Departure')} ${_minuteTime(context, schedule!.expectedDepartureMinute!)} · ${schedule!.arrivalGraceMinutes} ${_t(context, 'min de tolerancia', 'min grace')}'
                          : _t(
                              context,
                              'Configúralo para identificar retardos y salidas anticipadas.',
                              'Set it to identify late arrivals and early departures.',
                            ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onConfigure,
                icon: const Icon(Icons.schedule_rounded),
                label: Text(_t(context, 'Configurar horario', 'Set schedule')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthlyReportCard extends StatelessWidget {
  const _MonthlyReportCard({
    required this.month,
    required this.recordCount,
    required this.lateCount,
    required this.incompleteCount,
    required this.totalWorked,
    required this.onPrevious,
    required this.onNext,
    required this.onExport,
  });

  final DateTime month;
  final int recordCount;
  final int lateCount;
  final int incompleteCount;
  final Duration totalWorked;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final hours = totalWorked.inHours;
    final minutes = totalWorked.inMinutes.remainder(60);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _t(context, 'Mes anterior', 'Previous month'),
                      onPressed: onPrevious,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(
                      localizations.formatMonthYear(month),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      tooltip: _t(context, 'Mes siguiente', 'Next month'),
                      onPressed: onNext,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: recordCount == 0 ? null : onExport,
                  icon: const Icon(Icons.download_outlined),
                  label: Text(_t(context, 'Exportar CSV', 'Export CSV')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 420
                    ? (constraints.maxWidth - 8) / 2
                    : 150.0;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ReportMetric(
                      width: width,
                      value: '$recordCount',
                      label: _t(context, 'Días registrados', 'Days recorded'),
                      icon: Icons.event_available_outlined,
                    ),
                    _ReportMetric(
                      width: width,
                      value: '$lateCount',
                      label: _t(context, 'Retardos', 'Late arrivals'),
                      icon: Icons.more_time_rounded,
                    ),
                    _ReportMetric(
                      width: width,
                      value: '$incompleteCount',
                      label: _t(context, 'Jornadas incompletas', 'Incomplete'),
                      icon: Icons.pending_actions_rounded,
                    ),
                    _ReportMetric(
                      width: width,
                      value: '${hours}h ${minutes}m',
                      label: _t(context, 'Horas registradas', 'Hours recorded'),
                      icon: Icons.hourglass_bottom_rounded,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.width,
    required this.value,
    required this.label,
    required this.icon,
  });

  final double width;
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScheduleDialog extends StatefulWidget {
  const _ScheduleDialog({required this.schedule});

  final TeacherAttendanceSchedule? schedule;

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late bool _enabled = widget.schedule?.isConfigured ?? false;
  late TimeOfDay _arrival = _timeOfDay(
    widget.schedule?.expectedArrivalMinute ?? 8 * 60,
  );
  late TimeOfDay _departure = _timeOfDay(
    widget.schedule?.expectedDepartureMinute ?? 15 * 60,
  );
  late final TextEditingController _grace = TextEditingController(
    text: '${widget.schedule?.arrivalGraceMinutes ?? 10}',
  );

  @override
  void dispose() {
    _grace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_t(context, 'Horario esperado', 'Expected schedule')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(_t(context, 'Usar horario', 'Use a schedule')),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          if (_enabled) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: _arrival,
                );
                if (selected != null) setState(() => _arrival = selected);
              },
              icon: const Icon(Icons.login_rounded),
              label: Text(
                '${_t(context, 'Entrada esperada', 'Expected arrival')}: ${_arrival.format(context)}',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showTimePicker(
                  context: context,
                  initialTime: _departure,
                );
                if (selected != null) setState(() => _departure = selected);
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                '${_t(context, 'Salida esperada', 'Expected departure')}: ${_departure.format(context)}',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _grace,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _t(
                  context,
                  'Tolerancia de entrada (minutos)',
                  'Arrival grace period (minutes)',
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_t(context, 'Cancelar', 'Cancel')),
      ),
      FilledButton(
        onPressed: () {
          final grace = int.tryParse(_grace.text) ?? -1;
          final arrivalMinute = _arrival.hour * 60 + _arrival.minute;
          final departureMinute = _departure.hour * 60 + _departure.minute;
          if (_enabled &&
              (departureMinute <= arrivalMinute || grace < 0 || grace > 240)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _t(
                    context,
                    'Revisa que la salida sea posterior y la tolerancia esté entre 0 y 240 minutos.',
                    'Make sure departure is later and grace is between 0 and 240 minutes.',
                  ),
                ),
              ),
            );
            return;
          }
          Navigator.pop(
            context,
            _ScheduleDraft(
              enabled: _enabled,
              arrivalMinute: arrivalMinute,
              departureMinute: departureMinute,
              graceMinutes: grace.clamp(0, 240),
            ),
          );
        },
        child: Text(_t(context, 'Guardar', 'Save')),
      ),
    ],
  );
}

final class _ScheduleDraft {
  const _ScheduleDraft({
    required this.enabled,
    required this.arrivalMinute,
    required this.departureMinute,
    required this.graceMinutes,
  });

  final bool enabled;
  final int arrivalMinute;
  final int departureMinute;
  final int graceMinutes;
}

TimeOfDay _timeOfDay(int minute) =>
    TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

String _minuteTime(BuildContext context, int minute) =>
    _timeOfDay(minute).format(context);

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

String _csvSafe(String value) {
  final trimmed = value.trimLeft();
  if (trimmed.startsWith('=') ||
      trimmed.startsWith('+') ||
      trimmed.startsWith('-') ||
      trimmed.startsWith('@')) {
    return "'$value";
  }
  return value;
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.record,
    required this.isLate,
    required this.leftEarly,
    required this.isSaving,
    required this.schoolName,
    required this.onArrival,
    required this.onDeparture,
  });

  final TeacherAttendanceRecord? record;
  final bool isLate;
  final bool leftEarly;
  final bool isSaving;
  final String schoolName;
  final Future<bool> Function() onArrival;
  final Future<bool> Function() onDeparture;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final localizations = MaterialLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.badge_outlined),
                    const SizedBox(width: 10),
                    Text(
                      localizations.formatFullDate(today),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                if (record != null)
                  Chip(
                    avatar: Icon(
                      record!.isOpen
                          ? Icons.timelapse
                          : Icons.check_circle_outline,
                      size: 18,
                    ),
                    label: Text(
                      record!.isOpen
                          ? _t(context, 'Jornada abierta', 'Workday open')
                          : isLate || leftEarly
                          ? _t(context, 'Revisar jornada', 'Review workday')
                          : _t(context, 'Jornada completa', 'Workday complete'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (record == null)
              Text(
                _t(
                  context,
                  'Registra tu llegada a $schoolName.',
                  'Record your arrival at $schoolName.',
                ),
              )
            else ...[
              Text(
                '${_t(context, 'Entrada', 'Arrival')}: ${_time(context, record!.arrivedAt)}',
              ),
              if (record!.departedAt != null)
                Text(
                  '${_t(context, 'Salida', 'Departure')}: ${_time(context, record!.departedAt!)}',
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _t(
                      context,
                      'Recuerda registrar la salida al terminar tu jornada.',
                      'Remember to record your departure when you finish your workday.',
                    ),
                  ),
                ),
              if (isLate)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _t(
                      context,
                      'Llegada posterior al horario esperado.',
                      'Arrival was after the expected time.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (leftEarly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _t(
                      context,
                      'Salida anterior al horario esperado.',
                      'Departure was earlier than expected.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (record == null)
                  FilledButton.icon(
                    onPressed: isSaving ? null : () => onArrival(),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      _t(context, 'Registrar entrada', 'Record arrival'),
                    ),
                  ),
                if (record != null && record!.isOpen)
                  FilledButton.tonalIcon(
                    onPressed: isSaving ? null : () => onDeparture(),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text(
                      _t(context, 'Registrar salida', 'Record departure'),
                    ),
                  ),
                if (isSaving)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CorrectionDialog extends StatefulWidget {
  const _CorrectionDialog({required this.record});

  final TeacherAttendanceRecord record;

  @override
  State<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<_CorrectionDialog> {
  late DateTime _arrival = widget.record.arrivedAt;
  late DateTime? _departure = widget.record.departedAt;
  late final TextEditingController _notes = TextEditingController(
    text: widget.record.notes ?? '',
  );

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_t(context, 'Corregir jornada', 'Correct workday')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _timeButton(
              context,
              _t(context, 'Entrada', 'Arrival'),
              _arrival,
              (value) => setState(() => _arrival = value),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                if (_departure == null) {
                  final value = await _pickTime(context, DateTime.now());
                  if (value != null) setState(() => _departure = value);
                } else {
                  final value = await _pickTime(context, _departure!);
                  if (value != null) setState(() => _departure = value);
                }
              },
              icon: Icon(
                _departure == null ? Icons.add_rounded : Icons.schedule_rounded,
              ),
              label: Text(
                _departure == null
                    ? _t(context, 'Agregar salida', 'Add departure')
                    : '${_t(context, 'Salida', 'Departure')}: ${_time(context, _departure!)}',
              ),
            ),
            if (_departure != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _departure = null),
                  child: Text(_t(context, 'Quitar salida', 'Clear departure')),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 240,
              decoration: InputDecoration(
                labelText: _t(context, 'Nota (opcional)', 'Note (optional)'),
              ),
            ),
            if (widget.record.wasCorrected)
              Text(
                _t(
                  context,
                  'Este registro ya fue corregido anteriormente.',
                  'This record was corrected previously.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t(context, 'Cancelar', 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_departure != null && _departure!.isBefore(_arrival)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      context,
                      'La salida no puede ser anterior a la entrada.',
                      'Departure cannot be earlier than arrival.',
                    ),
                  ),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _AttendanceCorrection(_arrival, _departure, _notes.text),
            );
          },
          child: Text(_t(context, 'Guardar', 'Save')),
        ),
      ],
    );
  }

  Widget _timeButton(
    BuildContext context,
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) => OutlinedButton.icon(
    onPressed: () async {
      final selected = await _pickTime(context, value);
      if (selected != null) onChanged(selected);
    },
    icon: const Icon(Icons.schedule_rounded),
    label: Text('$label: ${_time(context, value)}'),
  );
}

class _PastRecordDialog extends StatefulWidget {
  const _PastRecordDialog();

  @override
  State<_PastRecordDialog> createState() => _PastRecordDialogState();
}

class _PastRecordDialogState extends State<_PastRecordDialog> {
  late DateTime _date = DateTime.now().subtract(const Duration(days: 1));
  late DateTime _arrival = DateTime(_date.year, _date.month, _date.day, 8);
  DateTime? _departure;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final lastDay = DateTime(today.year, today.month, today.day - 1);
    return AlertDialog(
      title: Text(_t(context, 'Agregar día anterior', 'Add a past day')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _date.isAfter(lastDay) ? lastDay : _date,
                  firstDate: DateTime(2000),
                  lastDate: lastDay,
                );
                if (selected != null) {
                  setState(() {
                    _date = selected;
                    _arrival = DateTime(
                      selected.year,
                      selected.month,
                      selected.day,
                      _arrival.hour,
                      _arrival.minute,
                    );
                    if (_departure != null) {
                      _departure = DateTime(
                        selected.year,
                        selected.month,
                        selected.day,
                        _departure!.hour,
                        _departure!.minute,
                      );
                    }
                  });
                }
              },
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(
                MaterialLocalizations.of(context).formatMediumDate(_date),
              ),
            ),
            const SizedBox(height: 8),
            _timeButton(
              context,
              _t(context, 'Entrada', 'Arrival'),
              _arrival,
              (value) => setState(() => _arrival = value),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final value = await _pickTime(
                  context,
                  _departure ??
                      DateTime(_date.year, _date.month, _date.day, 15),
                );
                if (value != null) setState(() => _departure = value);
              },
              icon: Icon(
                _departure == null ? Icons.add_rounded : Icons.schedule_rounded,
              ),
              label: Text(
                _departure == null
                    ? _t(
                        context,
                        'Agregar salida (opcional)',
                        'Add departure (optional)',
                      )
                    : '${_t(context, 'Salida', 'Departure')}: ${_time(context, _departure!)}',
              ),
            ),
            if (_departure != null)
              TextButton(
                onPressed: () => setState(() => _departure = null),
                child: Text(_t(context, 'Quitar salida', 'Clear departure')),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 240,
              decoration: InputDecoration(
                labelText: _t(
                  context,
                  'Motivo o nota (opcional)',
                  'Reason or note (optional)',
                ),
              ),
            ),
            Text(
              _t(
                context,
                'El registro quedará marcado como capturado posteriormente.',
                'This entry will be marked as added later.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t(context, 'Cancelar', 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (_departure != null && _departure!.isBefore(_arrival)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      context,
                      'La salida no puede ser anterior a la entrada.',
                      'Departure cannot be earlier than arrival.',
                    ),
                  ),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _AttendanceCorrection(
                _arrival,
                _departure,
                _notes.text,
                date: _date,
              ),
            );
          },
          child: Text(_t(context, 'Guardar', 'Save')),
        ),
      ],
    );
  }

  Widget _timeButton(
    BuildContext context,
    String label,
    DateTime value,
    ValueChanged<DateTime> onChanged,
  ) => OutlinedButton.icon(
    onPressed: () async {
      final selected = await _pickTime(context, value);
      if (selected != null) onChanged(selected);
    },
    icon: const Icon(Icons.schedule_rounded),
    label: Text('$label: ${_time(context, value)}'),
  );
}

final class _AttendanceCorrection {
  const _AttendanceCorrection(
    this.arrivedAt,
    this.departedAt,
    this.notes, {
    this.date,
  });

  final DateTime arrivedAt;
  final DateTime? departedAt;
  final String? notes;
  final DateTime? date;
}

Future<DateTime?> _pickTime(BuildContext context, DateTime initial) async {
  final value = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (value == null) return null;
  return DateTime(
    initial.year,
    initial.month,
    initial.day,
    value.hour,
    value.minute,
  );
}

String _recordSummary(
  BuildContext context,
  TeacherAttendanceRecord record,
  TeacherAttendanceController controller,
) {
  final corrected = record.wasCorrected
      ? _t(context, ' · Modificado', ' · Edited')
      : '';
  final note = record.notes == null ? '' : '\n${record.notes}';
  final flags = <String>[
    if (controller.isLate(record)) _t(context, 'Retardo', 'Late'),
    if (record.isOpen)
      _t(context, 'Jornada abierta', 'Workday open')
    else if (controller.isIncomplete(record))
      _t(context, 'Salida anticipada', 'Early departure'),
  ];
  final status = flags.isEmpty ? '' : '\n${flags.join(' · ')}';
  if (record.departedAt == null) {
    return '${_t(context, 'Entrada', 'Arrival')}: ${_time(context, record.arrivedAt)} · ${_t(context, 'Sin salida', 'No departure')}$status$corrected$note';
  }
  return '${_t(context, 'Entrada', 'Arrival')}: ${_time(context, record.arrivedAt)} · ${_t(context, 'Salida', 'Departure')}: ${_time(context, record.departedAt!)}$status$corrected$note';
}

String _time(BuildContext context, DateTime value) =>
    MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(value));

String _t(BuildContext context, String spanish, String english) =>
    Localizations.localeOf(context).languageCode == 'en' ? english : spanish;
