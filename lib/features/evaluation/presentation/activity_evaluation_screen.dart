import 'dart:async';

import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/features/evaluation/presentation/activity_evaluation_controller.dart';
import 'package:aularaiz/features/evaluation/presentation/evaluation_localization.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ActivityEvaluationScreen extends StatefulWidget {
  const ActivityEvaluationScreen({required this.activity, super.key});

  final Activity activity;

  @override
  State<ActivityEvaluationScreen> createState() =>
      _ActivityEvaluationScreenState();
}

class _ActivityEvaluationScreenState extends State<ActivityEvaluationScreen> {
  final _searchController = TextEditingController();
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ActivityEvaluationController>().load(widget.activity);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<ActivityEvaluationController>();
    final visibleEntries = controller.visibleEntries;

    return PopScope(
      canPop: !controller.hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !controller.hasUnsavedChanges) return;
        final discard = await _confirmDiscard(context);
        if (discard && context.mounted) {
          controller.allowDiscard();
          Navigator.of(context).pop();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
            if (!controller.isSaving) {
              unawaited(controller.saveAll());
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.formativeEvaluation),
                  Text(
                    widget.activity.title,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                Tooltip(
                  message: l10n.evaluationShortcut,
                  child: FilledButton.icon(
                    onPressed: controller.isSaving
                        ? null
                        : () => unawaited(controller.saveAll()),
                    icon: controller.isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(l10n.saveEvaluations),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: SafeArea(
              child: controller.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : controller.entries.isEmpty
                  ? Center(
                      child: Text(
                        controller.error == null
                            ? l10n.noEvaluationRoster
                            : l10n.evaluationLoadError,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _EvaluationToolbar(
                                  controller: controller,
                                  activity: widget.activity,
                                  searchController: _searchController,
                                ),
                                if (controller.error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    l10n.evaluationSaveError,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                if (visibleEntries.isEmpty)
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(l10n.noFilteredStudents),
                                    ),
                                  )
                                else
                                  for (final entry in visibleEntries) ...[
                                    _EvaluationCard(entry: entry),
                                    const SizedBox(height: 12),
                                  ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _EvaluationToolbar extends StatelessWidget {
  const _EvaluationToolbar({
    required this.controller,
    required this.activity,
    required this.searchController,
  });

  final ActivityEvaluationController controller;
  final Activity activity;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final grades = activity.targetGrades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.evidenceSummary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(
                  avatar: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(
                    '${l10n.evaluatedCount}: ${controller.evaluatedCount}',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.schedule_outlined, size: 18),
                  label: Text(
                    '${l10n.pendingCount}: ${controller.pendingCount}',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isSaving
                      ? null
                      : controller.markAllDelivered,
                  icon: Icon(Icons.done_all_rounded, color: scheme.secondary),
                  label: Text(l10n.markAllDelivered),
                ),
                Text(
                  l10n.evaluationShortcut,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: searchController,
                    onChanged: controller.setQuery,
                    decoration: InputDecoration(
                      labelText: l10n.evaluationSearch,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<PrimaryGrade>(
                    initialValue: controller.gradeFilter,
                    hint: Text(l10n.allGrades),
                    decoration: InputDecoration(labelText: l10n.grade),
                    items: [
                      for (final grade in grades)
                        DropdownMenuItem(
                          value: grade,
                          child: Text(_gradeLabel(grade, l10n)),
                        ),
                    ],
                    onChanged: controller.setGradeFilter,
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<DeliveryStatus>(
                    initialValue: controller.deliveryFilter,
                    hint: Text(l10n.allDeliveryStates),
                    decoration: InputDecoration(labelText: l10n.delivery),
                    items: [
                      for (final status in DeliveryStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(l10n.deliveryStatusLabel(status)),
                        ),
                    ],
                    onChanged: controller.setDeliveryFilter,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    searchController.clear();
                    controller.clearFilters();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(l10n.clearFilters),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluationCard extends StatelessWidget {
  const _EvaluationCard({required this.entry});

  final ActivityEvaluationEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.read<ActivityEvaluationController>();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  entry.student.displayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(label: Text(_gradeLabel(entry.grade, l10n))),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DeliveryDropdown(entry: entry),
                      if (entry.deliveryStatus == DeliveryStatus.delivered) ...[
                        const SizedBox(height: 12),
                        _AchievementDropdown(entry: entry),
                      ],
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.delivery),
                    const SizedBox(height: 8),
                    SegmentedButton<DeliveryStatus>(
                      showSelectedIcon: false,
                      segments: [
                        for (final status in DeliveryStatus.values)
                          ButtonSegment(
                            value: status,
                            label: Text(l10n.deliveryStatusLabel(status)),
                          ),
                      ],
                      selected: <DeliveryStatus>{entry.deliveryStatus},
                      onSelectionChanged: (selection) {
                        controller.setDelivery(
                          entry.student.id,
                          selection.single,
                        );
                      },
                    ),
                    if (entry.deliveryStatus == DeliveryStatus.delivered) ...[
                      const SizedBox(height: 14),
                      Text(l10n.achievement),
                      const SizedBox(height: 8),
                      SegmentedButton<AchievementLevel>(
                        showSelectedIcon: false,
                        emptySelectionAllowed: true,
                        segments: [
                          for (final level in AchievementLevel.values)
                            ButtonSegment(
                              value: level,
                              label: Text(l10n.achievementLabel(level)),
                            ),
                        ],
                        selected: entry.achievement == null
                            ? <AchievementLevel>{}
                            : <AchievementLevel>{entry.achievement!},
                        onSelectionChanged: (selection) {
                          controller.setAchievement(
                            entry.student.id,
                            selection.isEmpty ? null : selection.single,
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              initialValue: entry.observation,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.observation,
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
              onChanged: (value) =>
                  controller.setObservation(entry.student.id, value),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryDropdown extends StatelessWidget {
  const _DeliveryDropdown({required this.entry});

  final ActivityEvaluationEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<DeliveryStatus>(
      initialValue: entry.deliveryStatus,
      decoration: InputDecoration(labelText: l10n.delivery),
      items: [
        for (final status in DeliveryStatus.values)
          DropdownMenuItem(
            value: status,
            child: Text(l10n.deliveryStatusLabel(status)),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          context.read<ActivityEvaluationController>().setDelivery(
            entry.student.id,
            value,
          );
        }
      },
    );
  }
}

class _AchievementDropdown extends StatelessWidget {
  const _AchievementDropdown({required this.entry});

  final ActivityEvaluationEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DropdownButtonFormField<AchievementLevel?>(
      initialValue: entry.achievement,
      decoration: InputDecoration(labelText: l10n.achievement),
      items: [
        DropdownMenuItem<AchievementLevel?>(
          value: null,
          child: Text(l10n.noAchievementYet),
        ),
        for (final level in AchievementLevel.values)
          DropdownMenuItem<AchievementLevel?>(
            value: level,
            child: Text(l10n.achievementLabel(level)),
          ),
      ],
      onChanged: (value) => context
          .read<ActivityEvaluationController>()
          .setAchievement(entry.student.id, value),
    );
  }
}

String _gradeLabel(PrimaryGrade grade, AppLocalizations l10n) {
  return switch (grade) {
    PrimaryGrade.first => l10n.grade1,
    PrimaryGrade.second => l10n.grade2,
    PrimaryGrade.third => l10n.grade3,
    PrimaryGrade.fourth => l10n.grade4,
    PrimaryGrade.fifth => l10n.grade5,
    PrimaryGrade.sixth => l10n.grade6,
  };
}
