import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/attendance/presentation/attendance_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({required this.group, super.key});

  final TeachingGroup group;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AttendanceController>().load(widget.group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AttendanceController>();
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !controller.isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !controller.isDirty) return;
        final discard = await _confirmDiscard(context);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.attendanceTitle),
              Text(
                widget.group.name,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : controller.error != null
              ? _ErrorState(message: l10n.attendanceLoadError)
              : _MonthlyAttendanceGrid(controller: controller),
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.discardChangesTitle),
            content: Text(l10n.discardChangesBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.keepEditing),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.discardChanges),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _MonthlyAttendanceGrid extends StatelessWidget {
  const _MonthlyAttendanceGrid({required this.controller});

  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final month = controller.selectedMonth;
    final groupRate = controller.groupSummary.rate;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.previousMonth,
                        onPressed: () => _changeMonth(context, -1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 220),
                        child: Text(
                          MaterialLocalizations.of(context)
                              .formatMonthYear(month),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.nextMonth,
                        onPressed: () => _changeMonth(context, 1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (groupRate != null)
                        Chip(
                          avatar: const Icon(Icons.insights_rounded, size: 18),
                          label: Text(
                            _label(
                              context,
                              'Asistencia del grupo: ${(groupRate * 100).round()}%',
                              'Class attendance: ${(groupRate * 100).round()}%',
                            ),
                          ),
                        ),
                      FilledButton.icon(
                        onPressed: controller.isSaving || !controller.isDirty
                            ? null
                            : () async {
                                final saved = await controller.saveMonth();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      saved
                                          ? _label(
                                              context,
                                              'Asistencia guardada.',
                                              'Attendance saved.',
                                            )
                                          : l10n.attendanceLoadError,
                                    ),
                                  ),
                                );
                              },
                        icon: controller.isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(l10n.saveAttendance),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _label(
                  context,
                  'Haz clic en ✓ bajo un día para marcar al grupo presente y luego cambia sólo las excepciones. También puedes elegir directamente P, A, R o J en cada alumno.',
                  'Use ✓ under a date to mark the class present, then change only exceptions. You can also choose P, A, R or J for each student.',
                ),
              ),
              const SizedBox(height: 16),
              if (controller.monthStudents.isEmpty)
                Expanded(
                  child: _EmptyState(
                    message: _label(
                      context,
                      'No hay alumnos matriculados durante este mes.',
                      'There are no students enrolled during this month.',
                    ),
                  ),
                )
              else
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 72,
                            horizontalMargin: 14,
                            columnSpacing: 10,
                            columns: [
                              DataColumn(
                                label: SizedBox(
                                  width: 210,
                                  child: Text(l10n.student),
                                ),
                              ),
                              for (final date in controller.monthDates)
                                DataColumn(
                                  label: _DayHeader(
                                    date: date,
                                    dirty: controller.isDateDirty(date),
                                    onMarkPresent: () =>
                                        controller.markDayPresent(date),
                                  ),
                                ),
                              DataColumn(
                                numeric: true,
                                label: SizedBox(
                                  width: 76,
                                  child: Text(
                                    _label(context, '% Asist.', '% Attend.'),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                            rows: [
                              for (final student in controller.monthStudents)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      SizedBox(
                                        width: 210,
                                        child: Text(
                                          '${student.listNumber}. ${student.displayName}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    for (final date in controller.monthDates)
                                      DataCell(
                                        _AttendanceCell(
                                          active: controller.isStudentActiveOn(
                                            student.studentId,
                                            date,
                                          ),
                                          status: controller.statusFor(
                                            student.studentId,
                                            date,
                                          ),
                                          onChanged: (status) =>
                                              controller.setMonthStatus(
                                                student.studentId,
                                                date,
                                                status,
                                              ),
                                        ),
                                      ),
                                    DataCell(
                                      _AttendanceRateCell(
                                        summary: controller.summaryFor(
                                          student.studentId,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LegendItem(
                    status: AttendanceStatus.present,
                    label: _label(context, 'P = Presente', 'P = Present'),
                  ),
                  _LegendItem(
                    status: AttendanceStatus.absent,
                    label: _label(context, 'A = Ausente', 'A = Absent'),
                  ),
                  _LegendItem(
                    status: AttendanceStatus.late,
                    label: _label(context, 'R = Retardo', 'R = Late'),
                  ),
                  _LegendItem(
                    status: AttendanceStatus.justifiedAbsence,
                    label: _label(
                      context,
                      'J = Falta justificada',
                      'J = Justified absence',
                    ),
                  ),
                  Text(
                    _label(
                      context,
                      '— = no inscrito / sin pase de lista',
                      '— = not enrolled / no attendance saved',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _label(
                  context,
                  'El porcentaje cuenta Presente y Retardo como asistencia y usa sólo los días con pase de lista registrado.',
                  'The percentage counts Present and Late as attendance and uses only days with recorded attendance.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeMonth(BuildContext context, int delta) async {
    if (controller.isDirty) {
      final l10n = AppLocalizations.of(context);
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.discardChangesTitle),
          content: Text(l10n.discardChangesBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.keepEditing),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.discardChanges),
            ),
          ],
        ),
      );
      if (discard != true || !context.mounted) return;
    }
    final month = controller.selectedMonth;
    await controller.selectMonth(DateTime(month.year, month.month + delta));
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.dirty,
    required this.onMarkPresent,
  });

  final DateTime date;
  final bool dirty;
  final VoidCallback onMarkPresent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${date.day}', style: Theme.of(context).textTheme.labelLarge),
          Text(
            _weekdayLabel(context, date),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              tooltip: _label(
                context,
                'Marcar este día: todos presentes',
                'Mark this day: everyone present',
              ),
              onPressed: onMarkPresent,
              icon: Icon(
                dirty ? Icons.check_circle_rounded : Icons.done_all_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceCell extends StatelessWidget {
  const _AttendanceCell({
    required this.active,
    required this.status,
    required this.onChanged,
  });

  final bool active;
  final AttendanceStatus? status;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return const SizedBox(width: 40, child: Center(child: Text('—')));
    }

    final background = _statusBackground(context, status);
    final foreground = _statusForeground(context, status);
    return PopupMenuButton<AttendanceStatus>(
      tooltip: _label(context, 'Cambiar asistencia', 'Change attendance'),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final value in AttendanceStatus.values)
          PopupMenuItem(
            value: value,
            child: Row(
              children: [
                Icon(_statusIcon(value), size: 18),
                const SizedBox(width: 10),
                Text(_statusLabel(value, AppLocalizations.of(context))),
              ],
            ),
          ),
      ],
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: foreground.withValues(alpha: status == null ? 0.18 : 0.35),
          ),
        ),
        child: Center(
          child: status == null
              ? Text('—', style: TextStyle(color: foreground))
              : Tooltip(
                  message: _statusLabel(status!, AppLocalizations.of(context)),
                  child: Text(
                    _statusCode(status!),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _AttendanceRateCell extends StatelessWidget {
  const _AttendanceRateCell({required this.summary});

  final MonthlyAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final rate = summary.rate;
    if (rate == null) {
      return SizedBox(
        width: 76,
        child: Center(
          child: Text(
            '—',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      );
    }
    final percent = (rate * 100).round();
    return Tooltip(
      message: _label(
        context,
        '${summary.attended} asistencias de ${summary.recorded} registros',
        '${summary.attended} attended of ${summary.recorded} records',
      ),
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _rateColor(context, rate).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$percent%',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: _rateColor(context, rate),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.status, required this.label});

  final AttendanceStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _statusBackground(context, status),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _statusForeground(context, status).withValues(alpha: 0.35),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Color _statusBackground(BuildContext context, AttendanceStatus? status) {
  if (status == null) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }
  return switch (status) {
    AttendanceStatus.present => Colors.green.withValues(alpha: 0.18),
    AttendanceStatus.absent => Theme.of(context).colorScheme.errorContainer,
    AttendanceStatus.late => Colors.orange.withValues(alpha: 0.22),
    AttendanceStatus.justifiedAbsence => Colors.blue.withValues(alpha: 0.18),
  };
}

Color _statusForeground(BuildContext context, AttendanceStatus? status) {
  if (status == null) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
  return switch (status) {
    AttendanceStatus.present => Colors.green.shade800,
    AttendanceStatus.absent => Theme.of(context).colorScheme.onErrorContainer,
    AttendanceStatus.late => Colors.orange.shade900,
    AttendanceStatus.justifiedAbsence => Colors.blue.shade800,
  };
}

Color _rateColor(BuildContext context, double rate) {
  if (rate >= 0.9) return Colors.green.shade700;
  if (rate >= 0.8) return Colors.blue.shade700;
  if (rate >= 0.7) return Colors.orange.shade800;
  return Theme.of(context).colorScheme.error;
}

String _weekdayLabel(BuildContext context, DateTime date) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  return switch (date.weekday) {
    DateTime.monday => english ? 'Mon' : 'Lun',
    DateTime.tuesday => english ? 'Tue' : 'Mar',
    DateTime.wednesday => english ? 'Wed' : 'Mié',
    DateTime.thursday => english ? 'Thu' : 'Jue',
    DateTime.friday => english ? 'Fri' : 'Vie',
    DateTime.saturday => english ? 'Sat' : 'Sáb',
    DateTime.sunday => english ? 'Sun' : 'Dom',
    _ => '',
  };
}

String _statusCode(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => 'P',
  AttendanceStatus.absent => 'A',
  AttendanceStatus.late => 'R',
  AttendanceStatus.justifiedAbsence => 'J',
};

IconData _statusIcon(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => Icons.check_circle_outline_rounded,
  AttendanceStatus.absent => Icons.cancel_outlined,
  AttendanceStatus.late => Icons.schedule_rounded,
  AttendanceStatus.justifiedAbsence => Icons.fact_check_outlined,
};

String _statusLabel(AttendanceStatus status, AppLocalizations l10n) =>
    switch (status) {
      AttendanceStatus.present => l10n.present,
      AttendanceStatus.absent => l10n.absent,
      AttendanceStatus.late => l10n.late,
      AttendanceStatus.justifiedAbsence => l10n.justifiedAbsence,
    };

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_available_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}

String _label(BuildContext context, String es, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : es;
