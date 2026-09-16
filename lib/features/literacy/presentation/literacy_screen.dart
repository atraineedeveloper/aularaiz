import 'package:aularaiz/app/layout/app_state_panel.dart';
import 'package:aularaiz/app/layout/responsive_layout.dart';
import 'package:aularaiz/domain/literacy/literacy_assessment.dart';
import 'package:aularaiz/domain/literacy/reading_level.dart';
import 'package:aularaiz/domain/literacy/writing_level.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/literacy/presentation/literacy_controller.dart';
import 'package:aularaiz/features/student_record/presentation/student_record_localization.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LiteracyScreen extends StatefulWidget {
  const LiteracyScreen({required this.group, this.embedded = false, super.key});

  final TeachingGroup group;
  final bool embedded;

  @override
  State<LiteracyScreen> createState() => _LiteracyScreenState();
}

class _LiteracyScreenState extends State<LiteracyScreen> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LiteracyController>().load(widget.group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LiteracyController>();
    final layout = ResponsiveLayoutInfo.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(l10n.literacyTitle)),
      body: SafeArea(
        top: !widget.embedded,
        child: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.error != null
            ? Padding(
                padding: EdgeInsets.all(layout.pagePadding),
                child: AppStatePanel(
                  icon: Icons.menu_book_outlined,
                  title: _copy(context).loadError,
                  message: _copy(context).loadErrorMessage,
                  actionLabel: l10n.retry,
                  onAction: () => controller.load(widget.group),
                ),
              )
            : RefreshIndicator(
                onRefresh: () => controller.load(widget.group),
                child: ListView(
                  padding: EdgeInsets.all(layout.pagePadding),
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: _LiteracyContent(
                        group: widget.group,
                        controller: controller,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _LiteracyContent extends StatelessWidget {
  const _LiteracyContent({required this.group, required this.controller});

  final TeachingGroup group;
  final LiteracyController controller;

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context);
    final theme = Theme.of(context);
    final layout = ResponsiveLayoutInfo.of(context);
    final entries = controller.filteredEntries;
    final compact = layout.isCompactWidth || layout.isPhoneLandscape;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(copy.title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          compact ? copy.compactSubtitle : copy.subtitle,
          style: theme.textTheme.bodyLarge,
        ),
        SizedBox(height: layout.preferDenseUi ? 16 : 24),
        _SummaryCards(controller: controller, compact: compact),
        const SizedBox(height: 16),
        _FilterBar(controller: controller),
        const SizedBox(height: 16),
        if (controller.entries.isEmpty)
          AppStatePanel(
            icon: Icons.groups_outlined,
            title: copy.emptyTitle,
            message: copy.emptyMessage,
          )
        else if (entries.isEmpty)
          AppStatePanel(
            icon: Icons.filter_alt_off_outlined,
            title: copy.emptyFilterTitle,
            message: copy.emptyFilterMessage,
          )
        else
          _LiteracyRoster(
            group: group,
            entries: entries,
            saving: controller.isSaving,
          ),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller, required this.compact});

  final LiteracyController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context);
    final cards = [
      _SummaryMetric(
        icon: Icons.groups_outlined,
        label: copy.students,
        value: controller.activeStudentCount.toString(),
      ),
      _SummaryMetric(
        icon: Icons.fact_check_outlined,
        label: copy.assessed,
        value: controller.assessedCount.toString(),
      ),
      _SummaryMetric(
        icon: Icons.pending_actions_outlined,
        label: copy.pending,
        value: controller.pendingCount.toString(),
      ),
      _SummaryMetric(
        icon: Icons.priority_high_rounded,
        label: copy.prioritySupport,
        value: controller.prioritySupportCount.toString(),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = compact ? (constraints.maxWidth - 8) / 2 : 240.0;
        return Wrap(
          spacing: compact ? 8 : 12,
          runSpacing: compact ? 8 : 12,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final layout = ResponsiveLayoutInfo.of(context);
    final compact = layout.isCompactWidth || layout.isPhoneLandscape;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: compact ? 18 : 20,
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              child: Icon(icon, size: compact ? 18 : 22),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final LiteracyController controller;

  @override
  Widget build(BuildContext context) {
    final copy = _copy(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(copy.allFilter),
          selected: controller.filter == LiteracyFilter.all,
          onSelected: (_) => controller.setFilter(LiteracyFilter.all),
        ),
        ChoiceChip(
          label: Text(copy.pendingFilter),
          selected: controller.filter == LiteracyFilter.pending,
          onSelected: (_) => controller.setFilter(LiteracyFilter.pending),
        ),
        ChoiceChip(
          label: Text(copy.priorityFilter),
          selected: controller.filter == LiteracyFilter.prioritySupport,
          onSelected: (_) =>
              controller.setFilter(LiteracyFilter.prioritySupport),
        ),
        if (controller.historicalStudentCount > 0)
          ChoiceChip(
            label: Text(
              '${copy.historicalFilter} (${controller.historicalStudentCount})',
            ),
            selected: controller.filter == LiteracyFilter.historical,
            onSelected: (_) => controller.setFilter(LiteracyFilter.historical),
          ),
      ],
    );
  }
}

class _LiteracyRoster extends StatelessWidget {
  const _LiteracyRoster({
    required this.group,
    required this.entries,
    required this.saving,
  });

  final TeachingGroup group;
  final List<LiteracyRosterEntry> entries;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in entries) ...[
          _LiteracyStudentCard(
            entry: entry,
            showGrade: group.isMultigrade,
            saving: saving,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LiteracyStudentCard extends StatelessWidget {
  const _LiteracyStudentCard({
    required this.entry,
    required this.showGrade,
    required this.saving,
  });

  final LiteracyRosterEntry entry;
  final bool showGrade;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final assessment = entry.latestAssessment;
    final copy = _copy(context);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final priority = entry.needsPrioritySupport;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(entry.enrollment.listNumber.toString()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.student.displayName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (showGrade)
                            _TinyBadge('${entry.enrollment.grade.number}°'),
                          if (!entry.isActive) _TinyBadge(copy.inactive),
                          if (priority)
                            _TinyBadge(
                              copy.needsSupport,
                              color: scheme.errorContainer,
                              textColor: scheme.onErrorContainer,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: saving ? null : () => _showLiteracyDialog(context),
                  icon: Icon(
                    assessment == null
                        ? Icons.add_rounded
                        : Icons.edit_outlined,
                  ),
                  label: Text(
                    assessment == null
                        ? copy.register
                        : l10n.literacyEditAction,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (assessment == null)
              Text(copy.noAssessment)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LevelChip(
                    label: l10n.literacyReadingLevel,
                    value: _readingLevelLabel(assessment.readingLevel, l10n),
                  ),
                  _LevelChip(
                    label: l10n.literacyWritingLevel,
                    value: _writingLevelLabel(assessment.writingLevel, l10n),
                  ),
                  _TinyBadge(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(assessment.assessedAt.toLocal()),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLiteracyDialog(BuildContext context) async {
    final draft = await showDialog<_LiteracyDraft>(
      context: context,
      builder: (context) => _LiteracyDialog(
        studentName: entry.student.displayName,
        assessment: entry.latestAssessment,
      ),
    );
    if (draft == null || !context.mounted) return;

    final saved = await context.read<LiteracyController>().saveAssessment(
      entry: entry,
      assessedAt: draft.assessedAt,
      writingLevel: draft.writingLevel,
      readingLevel: draft.readingLevel,
      notes: draft.notes,
    );
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).literacySaveError)),
      );
    }
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge(this.text, {this.color, this.textColor});

  final String text;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: textColor ?? scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _LiteracyDialog extends StatefulWidget {
  const _LiteracyDialog({required this.studentName, this.assessment});

  final String studentName;
  final LiteracyAssessment? assessment;

  @override
  State<_LiteracyDialog> createState() => _LiteracyDialogState();
}

class _LiteracyDialogState extends State<_LiteracyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  late DateTime _date;
  WritingLevel? _writingLevel;
  ReadingLevel? _readingLevel;

  @override
  void initState() {
    super.initState();
    final assessment = widget.assessment;
    _date = assessment?.assessedAt.toLocal() ?? DateTime.now();
    _writingLevel = assessment?.writingLevel;
    _readingLevel = assessment?.readingLevel;
    _notesController = TextEditingController(text: assessment?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final copy = _copy(context);
    return AlertDialog(
      title: Text(
        widget.assessment == null ? copy.register : l10n.literacyEdit,
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.studentName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.literacyAssessmentDate),
                  subtitle: Text(
                    MaterialLocalizations.of(context).formatMediumDate(_date),
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ReadingLevel>(
                  initialValue: _readingLevel,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.literacyReadingLevel,
                  ),
                  items: [
                    for (final level in ReadingLevel.values)
                      DropdownMenuItem(
                        value: level,
                        child: Text(_readingLevelLabel(level, l10n)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _readingLevel = value),
                  validator: (value) =>
                      value == null ? l10n.requiredField : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WritingLevel>(
                  initialValue: _writingLevel,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.literacyWritingLevel,
                  ),
                  items: [
                    for (final level in WritingLevel.values)
                      DropdownMenuItem(
                        value: level,
                        child: Text(_writingLevelLabel(level, l10n)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _writingLevel = value),
                  validator: (value) =>
                      value == null ? l10n.requiredField : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: l10n.literacyNotesOptional,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _LiteracyDraft(
        assessedAt: _date,
        writingLevel: _writingLevel!,
        readingLevel: _readingLevel!,
        notes: _notesController.text,
      ),
    );
  }
}

final class _LiteracyDraft {
  const _LiteracyDraft({
    required this.assessedAt,
    required this.writingLevel,
    required this.readingLevel,
    required this.notes,
  });

  final DateTime assessedAt;
  final WritingLevel writingLevel;
  final ReadingLevel readingLevel;
  final String notes;
}

final class _LiteracyCopy {
  const _LiteracyCopy._({
    required this.title,
    required this.subtitle,
    required this.compactSubtitle,
    required this.students,
    required this.assessed,
    required this.pending,
    required this.prioritySupport,
    required this.allFilter,
    required this.pendingFilter,
    required this.priorityFilter,
    required this.historicalFilter,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyFilterTitle,
    required this.emptyFilterMessage,
    required this.noAssessment,
    required this.register,
    required this.inactive,
    required this.needsSupport,
    required this.loadError,
    required this.loadErrorMessage,
  });

  final String title;
  final String subtitle;
  final String compactSubtitle;
  final String students;
  final String assessed;
  final String pending;
  final String prioritySupport;
  final String allFilter;
  final String pendingFilter;
  final String priorityFilter;
  final String historicalFilter;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyFilterTitle;
  final String emptyFilterMessage;
  final String noAssessment;
  final String register;
  final String inactive;
  final String needsSupport;
  final String loadError;
  final String loadErrorMessage;
}

_LiteracyCopy _copy(BuildContext context) {
  final localeName = AppLocalizations.of(context).localeName;
  final english = localeName.startsWith('en');
  if (english) {
    return const _LiteracyCopy._(
      title: 'Literacy',
      subtitle: 'Track the reading and writing level of each student to identify who needs priority support.',
      compactSubtitle:
          'Track reading and writing to identify priority support.',
      students: 'Active students',
      assessed: 'Assessed',
      pending: 'Without assessment',
      prioritySupport: 'Priority support',
      allFilter: 'All',
      pendingFilter: 'Without assessment',
      priorityFilter: 'Priority support',
      historicalFilter: 'Historical',
      emptyTitle: 'No students yet',
      emptyMessage: 'Add students to the group before recording literacy.',
      emptyFilterTitle: 'No students in this filter',
      emptyFilterMessage: 'Try another filter or record a new assessment.',
      noAssessment: 'No literacy assessment recorded.',
      register: 'Record level',
      inactive: 'Historical',
      needsSupport: 'Needs support',
      loadError: 'Literacy could not be loaded',
      loadErrorMessage: 'Check the data and try again.',
    );
  }
  return const _LiteracyCopy._(
    title: 'Lectoescritura',
    subtitle: 'Registra el nivel de lectura y escritura de cada alumno para detectar quién necesita apoyo prioritario.',
    compactSubtitle:
        'Diagnostica lectura y escritura para detectar apoyo prioritario.',
    students: 'Alumnos activos',
    assessed: 'Evaluados',
    pending: 'Sin diagn\u00F3stico',
    prioritySupport: 'Apoyo prioritario',
    allFilter: 'Todos',
    pendingFilter: 'Sin diagnóstico',
    priorityFilter: 'Apoyo prioritario',
    historicalFilter: 'Hist\u00F3ricos',
    emptyTitle: 'Aún no hay alumnos',
    emptyMessage: 'Agrega alumnos al grupo antes de registrar lectoescritura.',
    emptyFilterTitle: 'No hay alumnos en este filtro',
    emptyFilterMessage: 'Prueba otro filtro o registra un diagnóstico nuevo.',
    noAssessment: 'Sin diagnóstico de lectoescritura.',
    register: 'Registrar nivel',
    inactive: 'Histórico',
    needsSupport: 'Requiere apoyo',
    loadError: 'No se pudo cargar lectoescritura',
    loadErrorMessage: 'Revisa los datos e inténtalo de nuevo.',
  );
}

String _writingLevelLabel(WritingLevel level, AppLocalizations l10n) {
  return switch (level) {
    WritingLevel.presyllabic => l10n.writingPresyllabic,
    WritingLevel.syllabic => l10n.writingSyllabic,
    WritingLevel.syllabicAlphabetic => l10n.writingSyllabicAlphabetic,
    WritingLevel.alphabetic => l10n.writingAlphabetic,
  };
}

String _readingLevelLabel(ReadingLevel level, AppLocalizations l10n) {
  return switch (level) {
    ReadingLevel.doesNotRead => l10n.readingDoesNotRead,
    ReadingLevel.syllabic => l10n.readingSyllabic,
    ReadingLevel.wordByWord => l10n.readingWordByWord,
    ReadingLevel.sentence => l10n.readingSentence,
    ReadingLevel.fluent => l10n.readingFluent,
  };
}
