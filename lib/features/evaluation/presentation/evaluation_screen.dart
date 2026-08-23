import 'package:aularaiz/domain/evaluation/achievement_level.dart';
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
  const EvaluationScreen({required this.group, super.key});
  final TeachingGroup group;
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
      appBar: AppBar(title: Text(widget.group.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.evaluationTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _label(
                  context,
                  'Cada columna es una actividad. P = pendiente, T = entregó y falta evaluar, N = no entregó, D/S/E/R = nivel de logro.',
                  'Each column is an activity. P = pending, T = delivered awaiting evaluation, N = not delivered, D/S/E/R = achievement level.',
                ),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.evaluationSaveError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              if (controller.projects.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: controller.selectedProjectId,
                  decoration: InputDecoration(
                    labelText: _label(context, 'Proyecto', 'Project'),
                  ),
                  items: [
                    for (final project in controller.projects)
                      DropdownMenuItem(
                        value: project.id,
                        child: Text(project.title),
                      ),
                  ],
                  onChanged: controller.isLoading
                      ? null
                      : (value) {
                          if (value != null) controller.selectProject(value);
                        },
                ),
              const SizedBox(height: 14),
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

class _EvaluationMatrix extends StatelessWidget {
  const _EvaluationMatrix({required this.controller});
  final EvaluationController controller;

  @override
  Widget build(BuildContext context) {
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
              child: DataTable(
                headingRowHeight: 78,
                horizontalMargin: 14,
                columnSpacing: 12,
                columns: [
                  DataColumn(
                    label: SizedBox(
                      width: 220,
                      child: Text(_label(context, 'Alumno', 'Student')),
                    ),
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
                            width: 220,
                            child: Text(
                              student.student?.displayName ?? student.studentId,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        for (final option in controller.projectActivities)
                          DataCell(
                            _EvaluationCell(
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
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
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
        width: 64,
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
    if (row == null)
      return const SizedBox(width: 48, child: Center(child: Text('—')));
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
      child: SizedBox(
        width: 48,
        height: 44,
        child: Center(
          child: Text(
            _code(row!.evaluation),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
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
                if (value != null)
                  setState(() {
                    _delivery = value;
                    if (value != DeliveryStatus.delivered) _achievement = null;
                  });
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

String _code(dynamic evaluation) {
  if (evaluation.state == EvaluationState.pendingDeliveryDecision) return 'P';
  if (evaluation.state == EvaluationState.notDelivered) return 'N';
  if (evaluation.state == EvaluationState.deliveredAwaitingEvaluation)
    return 'T';
  return switch (evaluation.achievement as AchievementLevel?) {
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
