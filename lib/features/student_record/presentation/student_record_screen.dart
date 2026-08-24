import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:aularaiz/features/evaluation/presentation/evaluation_localization.dart';
import 'package:aularaiz/features/student_record/presentation/student_record_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudentRecordScreen extends StatefulWidget {
  const StudentRecordScreen({
    required this.group,
    required this.student,
    this.embedded = false,
    this.onBackToRecords,
    super.key,
  });

  final TeachingGroup group;
  final Student student;
  final bool embedded;
  final VoidCallback? onBackToRecords;

  @override
  State<StudentRecordScreen> createState() => _StudentRecordScreenState();
}

class _StudentRecordScreenState extends State<StudentRecordScreen> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StudentRecordController>().load(
        group: widget.group,
        student: widget.student,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<StudentRecordController>();

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(widget.student.displayName)),
      body: SafeArea(
        top: !widget.embedded,
        child: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.error != null && controller.record == null
            ? Center(child: Text(l10n.studentRecordLoadingError))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.embedded) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: widget.onBackToRecords,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: Text(l10n.studentRecordsTitle),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _Header(student: widget.student),
                        if (controller.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            l10n.studentRecordSaveError,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 900) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: _ProfileSection(
                                      controller: controller,
                                      onEdit: _editProfile,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 4,
                                    child: _EvidenceSection(
                                      controller: controller,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                _ProfileSection(
                                  controller: controller,
                                  onEdit: _editProfile,
                                ),
                                const SizedBox(height: 16),
                                _EvidenceSection(controller: controller),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _TimelineSection(
                          controller: controller,
                          onObservation: () =>
                              _addEntry(StudentRecordEntryKind.observation),
                          onAgreement: () =>
                              _addEntry(StudentRecordEntryKind.familyAgreement),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _editProfile() async {
    final controller = context.read<StudentRecordController>();
    final draft = await showDialog<_ProfileDraft>(
      context: context,
      builder: (context) => _ProfileDialog(
        strengths: controller.record?.strengths,
        difficulties: controller.record?.difficulties,
        supports: controller.record?.supports,
      ),
    );
    if (draft == null || !mounted) return;
    await controller.saveProfile(
      strengths: draft.strengths,
      difficulties: draft.difficulties,
      supports: draft.supports,
    );
  }

  Future<void> _addEntry(StudentRecordEntryKind kind) async {
    final draft = await showDialog<_EntryDraft>(
      context: context,
      builder: (context) => _EntryDialog(kind: kind),
    );
    if (draft == null || !mounted) return;
    await context.read<StudentRecordController>().addEntry(
      kind: kind,
      occurredAt: draft.date,
      text: draft.text,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              child: Text(student.givenNames.characters.first.toUpperCase()),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.displayName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.studentRecordTitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.controller, required this.onEdit});

  final StudentRecordController controller;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final record = controller.record;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.studentRecordProfile,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: controller.isSaving ? null : onEdit,
                  tooltip: l10n.editStudent,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProfileValue(
              icon: Icons.auto_awesome_outlined,
              label: l10n.studentRecordStrengths,
              value: record?.strengths,
            ),
            const Divider(height: 28),
            _ProfileValue(
              icon: Icons.trending_up_outlined,
              label: l10n.studentRecordDifficulties,
              value: record?.difficulties,
            ),
            const Divider(height: 28),
            _ProfileValue(
              icon: Icons.handshake_outlined,
              label: l10n.studentRecordSupports,
              value: record?.supports,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileValue extends StatelessWidget {
  const _ProfileValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(value ?? '—'),
            ],
          ),
        ),
      ],
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.controller});

  final StudentRecordController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.studentRecordEvidence,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.studentRecordAttendanceEvidence,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CountChip(
                  label: l10n.studentRecordPresent,
                  count: controller.attendanceCount(AttendanceStatus.present),
                ),
                _CountChip(
                  label: l10n.studentRecordAbsent,
                  count: controller.attendanceCount(AttendanceStatus.absent),
                ),
                _CountChip(
                  label: l10n.studentRecordLate,
                  count: controller.attendanceCount(AttendanceStatus.late),
                ),
                _CountChip(
                  label: l10n.studentRecordJustified,
                  count: controller.attendanceCount(
                    AttendanceStatus.justifiedAbsence,
                  ),
                ),
              ],
            ),
            if (controller.attendanceEvidence.isEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.studentRecordNoAttendanceEvidence),
            ] else ...[
              const SizedBox(height: 12),
              for (final evidence in controller.attendanceEvidence.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text(
                    MaterialLocalizations.of(context)
                        .formatCompactDate(evidence.date),
                  ),
                  trailing: Text(_attendanceLabel(evidence.status, l10n)),
                ),
            ],
            const Divider(height: 32),
            Text(
              l10n.studentRecordEvaluationEvidence,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (controller.evaluationEvidence.isEmpty)
              Text(l10n.studentRecordNoEvaluationEvidence)
            else
              for (final evidence in controller.evaluationEvidence.take(6))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_turned_in_outlined),
                  title: Text(evidence.activityTitle),
                  subtitle: evidence.evaluation.observation == null
                      ? null
                      : Text(evidence.evaluation.observation!),
                  trailing: Text(
                    _evaluationLabel(
                      evidence.evaluation.deliveryStatus,
                      evidence.evaluation.achievement,
                      l10n,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label · $count'));
  }
}

class _TimelineSection extends StatelessWidget {
  const _TimelineSection({
    required this.controller,
    required this.onObservation,
    required this.onAgreement,
  });

  final StudentRecordController controller;
  final VoidCallback onObservation;
  final VoidCallback onAgreement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Text(
                  l10n.studentRecordTimeline,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: controller.isSaving ? null : onObservation,
                      icon: const Icon(Icons.note_add_outlined),
                      label: Text(l10n.studentRecordAddObservation),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.isSaving ? null : onAgreement,
                      icon: const Icon(Icons.family_restroom_outlined),
                      label: Text(l10n.studentRecordAddAgreement),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.entries.isEmpty)
              Text(l10n.studentRecordTimelineEmpty)
            else
              for (final entry in controller.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    entry.kind == StudentRecordEntryKind.observation
                        ? Icons.visibility_outlined
                        : Icons.handshake_outlined,
                  ),
                  title: Text(
                    entry.kind == StudentRecordEntryKind.observation
                        ? l10n.studentRecordObservation
                        : l10n.studentRecordFamilyAgreement,
                  ),
                  subtitle: Text(entry.text),
                  trailing: Text(
                    MaterialLocalizations.of(context)
                        .formatCompactDate(entry.occurredAt.toLocal()),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.strengths,
    required this.difficulties,
    required this.supports,
  });

  final String? strengths;
  final String? difficulties;
  final String? supports;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _strengthsController;
  late final TextEditingController _difficultiesController;
  late final TextEditingController _supportsController;

  @override
  void initState() {
    super.initState();
    _strengthsController = TextEditingController(text: widget.strengths);
    _difficultiesController = TextEditingController(text: widget.difficulties);
    _supportsController = TextEditingController(text: widget.supports);
  }

  @override
  void dispose() {
    _strengthsController.dispose();
    _difficultiesController.dispose();
    _supportsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.studentRecordProfile),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _strengthsController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.studentRecordStrengths,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _difficultiesController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.studentRecordDifficulties,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _supportsController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: l10n.studentRecordSupports,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _ProfileDraft(
              strengths: _strengthsController.text,
              difficulties: _difficultiesController.text,
              supports: _supportsController.text,
            ),
          ),
          child: Text(l10n.studentRecordSaveProfile),
        ),
      ],
    );
  }
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.kind});

  final StudentRecordEntryKind kind;

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = widget.kind == StudentRecordEntryKind.observation
        ? l10n.studentRecordAddObservation
        : l10n.studentRecordAddAgreement;
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.studentRecordEntryDate),
                subtitle: Text(
                  MaterialLocalizations.of(context).formatCompactDate(_date),
                ),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _textController,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.studentRecordEntryText,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.requiredField
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.create)),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context)
        .pop(_EntryDraft(date: _date, text: _textController.text));
  }
}

final class _ProfileDraft {
  const _ProfileDraft({
    required this.strengths,
    required this.difficulties,
    required this.supports,
  });

  final String strengths;
  final String difficulties;
  final String supports;
}

final class _EntryDraft {
  const _EntryDraft({required this.date, required this.text});

  final DateTime date;
  final String text;
}

String _attendanceLabel(AttendanceStatus status, AppLocalizations l10n) {
  return switch (status) {
    AttendanceStatus.present => l10n.studentRecordPresent,
    AttendanceStatus.absent => l10n.studentRecordAbsent,
    AttendanceStatus.late => l10n.studentRecordLate,
    AttendanceStatus.justifiedAbsence => l10n.studentRecordJustified,
  };
}

String _evaluationLabel(
  DeliveryStatus deliveryStatus,
  AchievementLevel? achievement,
  AppLocalizations l10n,
) {
  if (deliveryStatus == DeliveryStatus.pending) return l10n.evaluationPending;
  if (deliveryStatus == DeliveryStatus.notDelivered) {
    return l10n.evaluationNotDelivered;
  }
  if (achievement == null) return l10n.evaluationAwaiting;
  return switch (achievement) {
    AchievementLevel.mastered => l10n.achievementMastered,
    AchievementLevel.sufficient => l10n.achievementSufficient,
    AchievementLevel.inProgress => l10n.achievementInProgress,
    AchievementLevel.requiresSupport => l10n.achievementRequiresSupport,
  };
}
