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
    if (!_loadStarted) {
      _loadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AttendanceController>().load(widget.group);
      });
    }
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
      child: DefaultTabController(
        length: 2,
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
            bottom: TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.today_rounded),
                  text: l10n.dailyAttendance,
                ),
                Tab(
                  icon: const Icon(Icons.calendar_month_rounded),
                  text: l10n.monthlyAttendance,
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : controller.error != null
                ? _ErrorState(message: l10n.attendanceLoadError)
                : TabBarView(
                    children: [
                      _DailyAttendanceView(controller: controller),
                      _MonthlyAttendanceView(controller: controller),
                    ],
                  ),
          ),
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

class _DailyAttendanceView extends StatelessWidget {
  const _DailyAttendanceView({required this.controller});

  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = controller.selectedDate;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final horizontalPadding = wide ? 32.0 : 16.0;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                controller.rows.isEmpty ? 20 : 0,
              ),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _pickDate(context),
                              icon: const Icon(Icons.event_rounded),
                              label: Text(
                                MaterialLocalizations.of(context)
                                    .formatFullDate(date),
                              ),
                            ),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: controller.rows.isEmpty
                                      ? null
                                      : controller.markAllPresent,
                                  icon: const Icon(Icons.done_all_rounded),
                                  label: Text(l10n.markAllPresent),
                                ),
                                FilledButton.icon(
                                  onPressed:
                                      controller.isSaving || !controller.isDirty
                                      ? null
                                      : () => controller.save(),
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
                        const SizedBox(height: 18),
                        _Metrics(controller: controller),
                        if (controller.rows.isEmpty) ...[
                          const SizedBox(height: 22),
                          _EmptyState(message: l10n.noStudentsForDate),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (controller.rows.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  22,
                  horizontalPadding,
                  10,
                ),
                sliver: SliverList.builder(
                  itemCount: controller.rows.length,
                  itemBuilder: (context, index) {
                    final row = controller.rows[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StudentAttendanceCard(
                            row: row,
                            compact: !wide,
                            onChanged: (status) {
                              controller.setStatus(row.studentId, status);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = controller.selectedDate;
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

    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(current.year - 2),
      lastDate: DateTime(current.year + 2),
    );
    if (selected != null && context.mounted) {
      await controller.selectDate(selected);
    }
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.controller});

  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final values = <(AttendanceStatus, String, IconData)>[
      (
        AttendanceStatus.present,
        l10n.present,
        Icons.check_circle_outline_rounded,
      ),
      (AttendanceStatus.absent, l10n.absent, Icons.cancel_outlined),
      (AttendanceStatus.late, l10n.late, Icons.schedule_rounded),
      (
        AttendanceStatus.justifiedAbsence,
        l10n.justifiedAbsence,
        Icons.fact_check_outlined,
      ),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final value in values)
          Chip(
            avatar: Icon(value.$3, size: 18),
            label: Text('${value.$2}: ${controller.count(value.$1)}'),
          ),
      ],
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  const _StudentAttendanceCard({
    required this.row,
    required this.compact,
    required this.onChanged,
  });

  final AttendanceStudentRow row;
  final bool compact;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statuses = <(AttendanceStatus, String, IconData)>[
      (AttendanceStatus.present, l10n.present, Icons.check_rounded),
      (AttendanceStatus.absent, l10n.absent, Icons.close_rounded),
      (AttendanceStatus.late, l10n.late, Icons.schedule_rounded),
      (
        AttendanceStatus.justifiedAbsence,
        l10n.justifiedAbsence,
        Icons.fact_check_outlined,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StudentIdentity(row: row),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final status in statuses)
                        ChoiceChip(
                          selected: row.status == status.$1,
                          avatar: Icon(status.$3, size: 18),
                          label: Text(status.$2),
                          onSelected: (_) => onChanged(status.$1),
                        ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _StudentIdentity(row: row)),
                  const SizedBox(width: 20),
                  SegmentedButton<AttendanceStatus>(
                    showSelectedIcon: false,
                    segments: [
                      for (final status in statuses)
                        ButtonSegment<AttendanceStatus>(
                          value: status.$1,
                          label: Text(status.$2),
                          icon: Icon(status.$3),
                        ),
                    ],
                    selected: <AttendanceStatus>{row.status},
                    onSelectionChanged: (selection) {
                      onChanged(selection.single);
                    },
                  ),
                ],
              ),
      ),
    );
  }
}

class _StudentIdentity extends StatelessWidget {
  const _StudentIdentity({required this.row});

  final AttendanceStudentRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(child: Text('${row.listNumber}')),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            row.displayName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _MonthlyAttendanceView extends StatelessWidget {
  const _MonthlyAttendanceView({required this.controller});

  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final month = controller.selectedMonth;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.previousMonth,
                      onPressed: () => controller.selectMonth(
                        DateTime(month.year, month.month - 1),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(context, month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.nextMonth,
                      onPressed: () => controller.selectMonth(
                        DateTime(month.year, month.month + 1),
                      ),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (controller.monthDays.isEmpty)
                  _EmptyState(message: l10n.noAttendanceThisMonth)
                else ...[
                  Text(
                    '${l10n.recordedDays}: ${controller.monthDays.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(l10n.student)),
                          for (final day in controller.monthDays)
                            DataColumn(label: Text('${day.date.day}')),
                        ],
                        rows: [
                          for (final student in controller.monthStudents)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${student.listNumber}. ${student.displayName}',
                                  ),
                                ),
                                for (final day in controller.monthDays)
                                  DataCell(
                                    Tooltip(
                                      message: _statusLabel(
                                        day.statusFor(student.studentId),
                                        l10n,
                                      ),
                                      child: Text(
                                        _statusCode(
                                          day.statusFor(student.studentId),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.attendanceLegend,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _monthLabel(BuildContext context, DateTime month) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatMonthYear(month);
  }

  String _statusCode(AttendanceStatus? status) {
    return switch (status) {
      AttendanceStatus.present => 'P',
      AttendanceStatus.absent => 'A',
      AttendanceStatus.late => 'R',
      AttendanceStatus.justifiedAbsence => 'J',
      null => '—',
    };
  }

  String _statusLabel(AttendanceStatus? status, AppLocalizations l10n) {
    return switch (status) {
      AttendanceStatus.present => l10n.present,
      AttendanceStatus.absent => l10n.absent,
      AttendanceStatus.late => l10n.late,
      AttendanceStatus.justifiedAbsence => l10n.justifiedAbsence,
      null => l10n.notApplicable,
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
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
