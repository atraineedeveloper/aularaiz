import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/evaluation/evaluation_state.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/evaluation/presentation/evaluation_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EvaluationScreen extends StatefulWidget {
  const EvaluationScreen({required this.group, super.key});

  final TeachingGroup group;

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EvaluationController>().load(widget.group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<EvaluationController>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.evaluationTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.evaluationHistoricalRosterHelp),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.evaluationSaveError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              if (controller.options.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: controller.selected?.activity.id,
                  decoration: InputDecoration(
                    labelText: l10n.evaluationActivity,
                  ),
                  items: [
                    for (final option in controller.options)
                      DropdownMenuItem(
                        value: option.activity.id,
                        child: Text(
                          '${option.project.title} · ${option.activity.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: controller.isLoading
                      ? null
                      : (value) {
                          if (value != null) controller.selectActivity(value);
                        },
                ),
              const SizedBox(height: 16),
              if (controller.options.isEmpty && !controller.isLoading)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Text(
                        l10n.evaluationNoActivities,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                )
              else if (controller.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _Metrics(metrics: controller.metrics),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DropdownButton<EvaluationFilter>(
                    value: controller.filter,
                    onChanged: (value) {
                      if (value != null) controller.setFilter(value);
                    },
                    items: [
                      for (final value in EvaluationFilter.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_filterLabel(value, l10n)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: controller.visibleRows.isEmpty
                      ? Center(child: Text(l10n.evaluationNoResults))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1000
                                ? 2
                                : 1;
                            final width =
                                (constraints.maxWidth - (columns - 1) * 12) /
                                columns;
                            return SingleChildScrollView(
                              child: Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final row in controller.visibleRows)
                                    SizedBox(
                                      width: width,
                                      child: _EvaluationCard(
                                        row: row,
                                        onEdit: () => _edit(row),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(EvaluationStudentRow row) async {
    final draft = MediaQuery.sizeOf(context).width < 700
        ? await showModalBottomSheet<_EvaluationDraft>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: _EvaluationEditor(row: row, sheet: true),
            ),
          )
        : await showDialog<_EvaluationDraft>(
            context: context,
            builder: (context) => _EvaluationEditor(row: row),
          );
    if (draft == null || !mounted) return;
    await context.read<EvaluationController>().save(
      studentId: row.studentId,
      deliveryStatus: draft.deliveryStatus,
      achievement: draft.achievement,
      observation: draft.observation,
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics});

  final EvaluationMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compliance = metrics.deliveryCompliance;
    final values = <(String, String)>[
      (l10n.evaluationStudents, '${metrics.total}'),
      (l10n.evaluationDeliveredMetric, '${metrics.delivered}'),
      (l10n.evaluationPendingMetric, '${metrics.pending}'),
      (
        l10n.evaluationCompliance,
        compliance == null
            ? l10n.evaluationNoDecision
            : '${(compliance * 100).round()}%',
      ),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final value in values)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value.$1, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(value.$2, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({required this.row, required this.onEdit});

  final EvaluationStudentRow row;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final evaluation = row.evaluation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text('${row.participant.grade.number}°')),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.student?.displayName ?? row.studentId,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(_stateLabel(evaluation.state, l10n))),
              ],
            ),
            if (evaluation.achievement != null) ...[
              const SizedBox(height: 10),
              Text(
                '${l10n.evaluationAchievement}: '
                '${_achievementLabel(evaluation.achievement!, l10n)}',
              ),
            ],
            if (evaluation.observation != null) ...[
              const SizedBox(height: 8),
              Text(evaluation.observation!),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onEdit,
                icon: const Icon(Icons.rate_review_outlined),
                label: Text(l10n.evaluationEdit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationEditor extends StatefulWidget {
  const _EvaluationEditor({required this.row, this.sheet = false});

  final EvaluationStudentRow row;
  final bool sheet;

  @override
  State<_EvaluationEditor> createState() => _EvaluationEditorState();
}

class _EvaluationEditorState extends State<_EvaluationEditor> {
  late DeliveryStatus _deliveryStatus;
  AchievementLevel? _achievement;
  late final TextEditingController _observationController;

  @override
  void initState() {
    super.initState();
    _deliveryStatus = widget.row.evaluation.deliveryStatus;
    _achievement = widget.row.evaluation.achievement;
    _observationController = TextEditingController(
      text: widget.row.evaluation.observation,
    );
  }

  @override
  void dispose() {
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: widget.sheet ? const EdgeInsets.all(24) : EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.row.student?.displayName ?? widget.row.studentId,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<DeliveryStatus>(
              initialValue: _deliveryStatus,
              decoration: InputDecoration(labelText: l10n.evaluationDelivery),
              items: [
                for (final status in DeliveryStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(_deliveryLabel(status, l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _deliveryStatus = value;
                  if (value != DeliveryStatus.delivered) _achievement = null;
                });
              },
            ),
            if (_deliveryStatus == DeliveryStatus.delivered) ...[
              const SizedBox(height: 16),
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
                    DropdownMenuItem<AchievementLevel?>(
                      value: level,
                      child: Text(_achievementLabel(level, l10n)),
                    ),
                ],
                onChanged: (value) => setState(() => _achievement = value),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _observationController,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.evaluationObservation,
              ),
            ),
            if (widget.sheet) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: Text(l10n.evaluationSave),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );

    if (widget.sheet) return content;
    return AlertDialog(
      title: Text(l10n.evaluationEdit),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.evaluationSave)),
      ],
    );
  }

  void _submit() {
    Navigator.of(context).pop(
      _EvaluationDraft(
        deliveryStatus: _deliveryStatus,
        achievement: _achievement,
        observation: _observationController.text,
      ),
    );
  }
}

final class _EvaluationDraft {
  const _EvaluationDraft({
    required this.deliveryStatus,
    required this.achievement,
    required this.observation,
  });

  final DeliveryStatus deliveryStatus;
  final AchievementLevel? achievement;
  final String observation;
}

String _deliveryLabel(DeliveryStatus status, AppLocalizations l10n) {
  return switch (status) {
    DeliveryStatus.pending => l10n.evaluationPending,
    DeliveryStatus.delivered => l10n.evaluationDelivered,
    DeliveryStatus.notDelivered => l10n.evaluationNotDelivered,
  };
}

String _stateLabel(EvaluationState state, AppLocalizations l10n) {
  return switch (state) {
    EvaluationState.pendingDeliveryDecision => l10n.evaluationPending,
    EvaluationState.deliveredAwaitingEvaluation => l10n.evaluationAwaiting,
    EvaluationState.notDelivered => l10n.evaluationNotDelivered,
    EvaluationState.deliveredAndEvaluated => l10n.evaluationEvaluated,
  };
}

String _achievementLabel(AchievementLevel level, AppLocalizations l10n) {
  return switch (level) {
    AchievementLevel.mastered => l10n.achievementMastered,
    AchievementLevel.sufficient => l10n.achievementSufficient,
    AchievementLevel.inProgress => l10n.achievementInProgress,
    AchievementLevel.requiresSupport => l10n.achievementRequiresSupport,
  };
}

String _filterLabel(EvaluationFilter filter, AppLocalizations l10n) {
  return switch (filter) {
    EvaluationFilter.all => l10n.evaluationAll,
    EvaluationFilter.pending => l10n.evaluationPending,
    EvaluationFilter.awaitingEvaluation => l10n.evaluationAwaiting,
    EvaluationFilter.notDelivered => l10n.evaluationNotDelivered,
    EvaluationFilter.evaluated => l10n.evaluationEvaluated,
  };
}
