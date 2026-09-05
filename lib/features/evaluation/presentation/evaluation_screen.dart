import 'package:aularaiz/app/errors/friendly_error_message.dart';
import 'package:aularaiz/app/layout/grade_filter.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/evaluation/evaluation_state.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/evaluation/presentation/evaluation_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({
    required this.group,
    this.embedded = false,
    super.key,
  });
  final TeachingGroup group;
  final bool embedded;
  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  bool _loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EvaluationController>().load(widget.group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EvaluationController>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(widget.group.name)),
      body: SafeArea(
        top: !widget.embedded,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.evaluationTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  friendlyErrorMessage(
                    context,
                    controller.error,
                    fallback: l10n.evaluationSaveError,
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              if (controller.projects.isNotEmpty)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: controller.selectedProjectId,
                  decoration: InputDecoration(
                    labelText: _label(context, 'Proyecto', 'Project'),
                  ),
                  items: [
                    for (final project in controller.projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: controller.isLoading
                      ? null
                      : (value) {
                          if (value != null) controller.selectProject(value);
                        },
                ),
              const SizedBox(height: 14),
              if (controller.projects.isNotEmpty) ...[
                _EvaluationToolbar(controller: controller, group: widget.group),
                if (!controller.isLoading &&
                    controller.projectActivities.any(
                      (option) =>
                          option.activity.occursOn == null ||
                          controller.hasMissingAttendance(option.activity.id),
                    ))
                  Text(
                    _label(
                          context,
                          'Falta fecha o asistencia por registrar en: ',
                          'Missing date or attendance for: ',
                        ) +
                        controller.projectActivities
                            .where(
                              (option) =>
                                  option.activity.occursOn == null ||
                                  controller.hasMissingAttendance(
                                    option.activity.id,
                                  ),
                            )
                            .map((option) => option.activity.displayIdentifier)
                            .join(', ') +
                        _label(
                          context,
                          '. Completa la fecha y la asistencia y pulsa Actualizar asistencia. Sin registro no se considera ausencia.',
                          '. Complete the date and attendance, then refresh attendance. Missing records are not absences.',
                        ),
                  ),
                const SizedBox(height: 8),
              ],
              if (controller.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.options.isEmpty)
                Expanded(
                  child: Center(child: Text(l10n.evaluationNoActivities)),
                )
              else if (controller.projectActivities.isEmpty)
                Expanded(
                  child: Center(child: Text(l10n.evaluationNoActivities)),
                )
              else
                Expanded(child: _EvaluationMatrix(controller: controller)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvaluationToolbar extends StatelessWidget {
  const _EvaluationToolbar({required this.controller, required this.group});
  final EvaluationController controller;
  final TeachingGroup group;

  Widget _filters(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (group.isMultigrade)
        GradeFilter(
          grades: controller.availableGrades,
          selected: controller.selectedGrade,
          grouped: controller.groupByGrade,
          onGrade: controller.setGrade,
          onGrouped: controller.setGroupByGrade,
          showGrouping: false,
        ),
      Tooltip(
        message: _label(
          context,
          'Incluye presentes y retardos. Elige Todos para recuperaciones.',
          'Includes present and late students. Choose Everyone for make-up work.',
        ),
        child: SizedBox(
          width: 220,
          child: DropdownButton<bool>(
            isExpanded: true,
            value: controller.attendeesOnly,
            items: [
              DropdownMenuItem(
                value: true,
                child: Text(
                  _label(context, 'Asistieron ese día', 'Attended that day'),
                ),
              ),
              DropdownMenuItem(
                value: false,
                child: Text(_label(context, 'Todos', 'Everyone')),
              ),
            ],
            onChanged: (value) {
              if (value != null) controller.setAttendeesOnly(value);
            },
          ),
        ),
      ),
      if (group.isMultigrade)
        PopupMenuButton<bool>(
          tooltip: _label(context, 'Vista', 'View'),
          onSelected: controller.setGroupByGrade,
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: !controller.groupByGrade,
              checked: controller.groupByGrade,
              child: Text(
                _label(context, 'Agrupar por grado', 'Group by grade'),
              ),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_label(context, 'Vista ▾', 'View ▾')),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (constraints.maxWidth >= 720 &&
            MediaQuery.textScalerOf(context).scale(14) <= 21)
          _filters(context)
        else
          TextButton.icon(
            icon: const Icon(Icons.filter_list),
            label: Text(_label(context, 'Filtros', 'Filters')),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(_label(context, 'Filtros', 'Filters')),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 480,
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (_, _) => _filters(dialogContext),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(_label(context, 'Listo', 'Done')),
                  ),
                ],
              ),
            ),
          ),
        IconButton(
          tooltip: _label(
            context,
            'Actualizar asistencia',
            'Refresh attendance',
          ),
          onPressed: controller.isLoading || controller.isSaving
              ? null
              : () => controller.load(group),
          icon: const Icon(Icons.refresh),
        ),
        TextButton.icon(
          icon: const Icon(Icons.help_outline),
          label: Text(
            _label(context, 'Significado de colores', 'Color legend'),
          ),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(
                _label(context, 'Significado de colores', 'Color legend'),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final item in [
                      ('P', _label(context, 'Pendiente', 'Pending')),
                      (
                        'T',
                        _label(
                          context,
                          'Entregó, falta evaluar',
                          'Delivered, awaiting evaluation',
                        ),
                      ),
                      ('N', _label(context, 'No entregó', 'Not delivered')),
                      ('D', _label(context, 'Dominado', 'Mastered')),
                      ('S', _label(context, 'Suficiente', 'Sufficient')),
                      ('E', _label(context, 'En proceso', 'In progress')),
                      (
                        'R',
                        _label(context, 'Requiere apoyo', 'Requires support'),
                      ),
                    ])
                      ListTile(
                        leading: _EvaluationBadge(code: item.$1, compact: true),
                        title: Text(item.$2),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(_label(context, 'Cerrar', 'Close')),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _EvaluationMatrix extends StatelessWidget {
  const _EvaluationMatrix({required this.controller});
  final EvaluationController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 720
          ? _mobileList(context)
          : _desktopMatrix(context, constraints.maxWidth),
    );
  }

  Widget _desktopMatrix(BuildContext context, double width) {
    if (controller.matrixRows.isEmpty) {
      return Center(
        child: Text(
          _label(
            context,
            'No hay alumnos para este filtro. Revisa la asistencia o selecciona Todos.',
            'No students match this filter. Check attendance or choose Everyone.',
          ),
        ),
      );
    }
    final behavior = ScrollConfiguration.of(context).copyWith(
      dragDevices: const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      },
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ScrollConfiguration(
        behavior: behavior,
        child: Scrollbar(
          thumbVisibility: true,
          trackVisibility: true,
          interactive: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: width - 8),
                child: DataTable(
                  headingRowHeight: 78,
                  horizontalMargin: 14,
                  columnSpacing: 12,
                  columns: [
                    DataColumn(
                      label: SizedBox(
                        width: 320,
                        child: Text(_label(context, 'Alumno', 'Student')),
                      ),
                    ),
                    if (controller.group?.isMultigrade == true)
                      DataColumn(
                        label: Text(_label(context, 'Grado', 'Grade')),
                      ),
                    for (final option in controller.projectActivities)
                      DataColumn(
                        label: _ActivityHeader(activity: option.activity),
                      ),
                  ],
                  rows: [
                    for (final student in controller.matrixRows)
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 320,
                              child: Text(
                                student.student?.displayName ??
                                    student.studentId,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (controller.group?.isMultigrade == true)
                            DataCell(Text(student.gradeLabel)),
                          for (final option in controller.projectActivities)
                            DataCell(
                              _EvaluationCell(
                                row:
                                    !controller.isVisibleForActivity(
                                      option.activity.id,
                                      student.studentId,
                                    )
                                    ? null
                                    : controller.cell(
                                        option.activity.id,
                                        student.studentId,
                                      ),
                                disabled: controller.isSaving,
                                onQuickSave: (draft) => controller.saveCell(
                                  activityId: option.activity.id,
                                  studentId: student.studentId,
                                  deliveryStatus: draft.delivery,
                                  achievement: draft.achievement,
                                ),
                                onDetails: () => _editDetails(
                                  context,
                                  controller,
                                  option.activity.id,
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
    );
  }

  Widget _mobileList(BuildContext context) {
    return ListView.separated(
      itemCount: controller.projectActivities.length,
      padding: const EdgeInsets.only(bottom: 24),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, activityIndex) {
        final option = controller.projectActivities[activityIndex];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.activity.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  option.activity.occursOn == null
                      ? _label(context, 'Sin fecha', 'No date')
                      : MaterialLocalizations.of(context)
                            .formatShortDate(option.activity.occursOn!),
                ),
                if (controller.visibleMatrixRowsFor(option.activity.id).isEmpty)
                  Text(
                    _label(
                      context,
                      'Sin alumnos para este filtro. Revisa la asistencia o selecciona Todos.',
                      'No students match this filter. Check attendance or choose Everyone.',
                    ),
                  ),
                for (final student in controller.visibleMatrixRowsFor(
                  option.activity.id,
                )) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      student.student?.displayName ?? student.studentId,
                    ),
                    subtitle: controller.group?.isMultigrade == true
                        ? Text(
                            '${controller.cell(option.activity.id, student.studentId)!.participant.grade.number}.º',
                          )
                        : null,
                    trailing: _EvaluationCell(
                      row: controller.cell(
                        option.activity.id,
                        student.studentId,
                      ),
                      disabled: controller.isSaving,
                      onQuickSave: (draft) => controller.saveCell(
                        activityId: option.activity.id,
                        studentId: student.studentId,
                        deliveryStatus: draft.delivery,
                        achievement: draft.achievement,
                      ),
                      onDetails: () => _editDetails(
                        context,
                        controller,
                        option.activity.id,
                        student.studentId,
                      ),
                    ),
                  ),
                  if (student != controller.matrixRows.last) const Divider(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editDetails(
    BuildContext context,
    EvaluationController controller,
    String activityId,
    String studentId,
  ) async {
    final row = controller.cell(activityId, studentId);
    if (row == null) return;
    final draft = await showDialog<_DetailedDraft>(
      context: context,
      builder: (_) => _DetailedEditor(row: row),
    );
    if (draft == null || !context.mounted) return;
    await controller.saveCell(
      activityId: activityId,
      studentId: studentId,
      deliveryStatus: draft.delivery,
      achievement: draft.achievement,
      observation: draft.observation,
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  const _ActivityHeader({required this.activity});
  final Activity activity;
  @override
  Widget build(BuildContext context) {
    final date = activity.occursOn == null
        ? _label(context, 'Sin fecha', 'No date')
        : MaterialLocalizations.of(context).formatShortDate(activity.occursOn!);
    return Tooltip(
      message: '${activity.title}\n$date',
      child: SizedBox(
        width: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              activity.displayIdentifier,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              date,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationCell extends StatelessWidget {
  const _EvaluationCell({
    required this.row,
    required this.disabled,
    required this.onQuickSave,
    required this.onDetails,
  });
  final EvaluationStudentRow? row;
  final bool disabled;
  final ValueChanged<_QuickDraft> onQuickSave;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    if (row == null) {
      return const SizedBox(width: 48, child: Center(child: Text('—')));
    }
    return PopupMenuButton<Object>(
      enabled: !disabled,
      tooltip: _label(context, 'Evaluar', 'Evaluate'),
      onSelected: (value) {
        if (value == 'details') onDetails();
        if (value is _QuickDraft) onQuickSave(value);
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: const _QuickDraft(DeliveryStatus.pending, null),
          child: Text('P · ${_label(context, 'Pendiente', 'Pending')}'),
        ),
        PopupMenuItem(
          value: const _QuickDraft(DeliveryStatus.delivered, null),
          child: Text(
            'T · ${_label(context, 'Entregó · evaluar después', 'Delivered · evaluate later')}',
          ),
        ),
        PopupMenuItem(
          value: const _QuickDraft(
            DeliveryStatus.delivered,
            AchievementLevel.mastered,
          ),
          child: Text('D · ${_label(context, 'Dominado', 'Mastered')}'),
        ),
        PopupMenuItem(
          value: const _QuickDraft(
            DeliveryStatus.delivered,
            AchievementLevel.sufficient,
          ),
          child: Text('S · ${_label(context, 'Suficiente', 'Sufficient')}'),
        ),
        PopupMenuItem(
          value: const _QuickDraft(
            DeliveryStatus.delivered,
            AchievementLevel.inProgress,
          ),
          child: Text('E · ${_label(context, 'En proceso', 'In progress')}'),
        ),
        PopupMenuItem(
          value: const _QuickDraft(
            DeliveryStatus.delivered,
            AchievementLevel.requiresSupport,
          ),
          child: Text(
            'R · ${_label(context, 'Requiere apoyo', 'Requires support')}',
          ),
        ),
        PopupMenuItem(
          value: const _QuickDraft(DeliveryStatus.notDelivered, null),
          child: Text('N · ${_label(context, 'No entregó', 'Not delivered')}'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'details',
          child: Text(
            _label(context, 'Detalle / observación…', 'Details / observation…'),
          ),
        ),
      ],
      child: _EvaluationBadge(code: _code(row!.evaluation)),
    );
  }
}

class _EvaluationBadge extends StatelessWidget {
  const _EvaluationBadge({required this.code, this.compact = false});
  final String code;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = switch (code) {
      'D' => Colors.green,
      'S' => Colors.blue,
      'E' => Colors.amber,
      'R' => Colors.orange,
      'N' => Colors.red,
      'T' => Colors.purple,
      _ => Colors.grey,
    };
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? palette.shade100 : palette.shade900;
    return Container(
      width: compact ? 28 : 44,
      height: compact ? 28 : 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark
            ? palette.shade900.withValues(alpha: 0.45)
            : palette.shade50,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: foreground.withValues(alpha: 0.4)),
      ),
      child: Text(
        code,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DetailedEditor extends StatefulWidget {
  const _DetailedEditor({required this.row});
  final EvaluationStudentRow row;
  @override
  State<_DetailedEditor> createState() => _DetailedEditorState();
}

class _DetailedEditorState extends State<_DetailedEditor> {
  late DeliveryStatus _delivery;
  AchievementLevel? _achievement;
  late final TextEditingController _observation;
  @override
  void initState() {
    super.initState();
    _delivery = widget.row.evaluation.deliveryStatus;
    _achievement = widget.row.evaluation.achievement;
    _observation = TextEditingController(
      text: widget.row.evaluation.observation,
    );
  }

  @override
  void dispose() {
    _observation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.row.student?.displayName ?? widget.row.studentId),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DeliveryStatus>(
              initialValue: _delivery,
              decoration: InputDecoration(labelText: l10n.evaluationDelivery),
              items: [
                for (final status in DeliveryStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(_deliveryLabel(status, l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _delivery = value;
                    if (value != DeliveryStatus.delivered) {
                      _achievement = null;
                    }
                  });
                }
              },
            ),
            if (_delivery == DeliveryStatus.delivered) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<AchievementLevel?>(
                initialValue: _achievement,
                decoration: InputDecoration(
                  labelText: l10n.evaluationAchievement,
                ),
                items: [
                  DropdownMenuItem<AchievementLevel?>(
                    value: null,
                    child: Text(l10n.evaluationAwaiting),
                  ),
                  for (final level in AchievementLevel.values)
                    DropdownMenuItem(
                      value: level,
                      child: Text(_achievementLabel(level, l10n)),
                    ),
                ],
                onChanged: (value) => setState(() => _achievement = value),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _observation,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.evaluationObservation,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _DetailedDraft(_delivery, _achievement, _observation.text),
          ),
          child: Text(l10n.evaluationSave),
        ),
      ],
    );
  }
}

final class _QuickDraft {
  const _QuickDraft(this.delivery, this.achievement);
  final DeliveryStatus delivery;
  final AchievementLevel? achievement;
}

final class _DetailedDraft extends _QuickDraft {
  const _DetailedDraft(super.delivery, super.achievement, this.observation);
  final String observation;
}

String _code(ActivityEvaluation evaluation) {
  if (evaluation.state == EvaluationState.pendingDeliveryDecision) {
    return 'P';
  }
  if (evaluation.state == EvaluationState.notDelivered) {
    return 'N';
  }
  if (evaluation.state == EvaluationState.deliveredAwaitingEvaluation) {
    return 'T';
  }
  return switch (evaluation.achievement) {
    AchievementLevel.mastered => 'D',
    AchievementLevel.sufficient => 'S',
    AchievementLevel.inProgress => 'E',
    AchievementLevel.requiresSupport => 'R',
    null => 'T',
  };
}

String _deliveryLabel(DeliveryStatus value, AppLocalizations l10n) =>
    switch (value) {
      DeliveryStatus.pending => l10n.evaluationPending,
      DeliveryStatus.delivered => l10n.evaluationDelivered,
      DeliveryStatus.notDelivered => l10n.evaluationNotDelivered,
    };
String _achievementLabel(AchievementLevel value, AppLocalizations l10n) =>
    switch (value) {
      AchievementLevel.mastered => l10n.achievementMastered,
      AchievementLevel.sufficient => l10n.achievementSufficient,
      AchievementLevel.inProgress => l10n.achievementInProgress,
      AchievementLevel.requiresSupport => l10n.achievementRequiresSupport,
    };
String _label(BuildContext context, String es, String en) =>
    Localizations.localeOf(context).languageCode == 'en' ? en : es;
