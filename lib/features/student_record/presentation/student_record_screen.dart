import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:aularaiz/features/student_record/presentation/student_record_controller.dart';
import 'package:aularaiz/features/student_record/presentation/student_record_localization.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudentRecordScreen extends StatefulWidget {
  const StudentRecordScreen({required this.student, super.key});

  final Student student;

  @override
  State<StudentRecordScreen> createState() => _StudentRecordScreenState();
}

class _StudentRecordScreenState extends State<StudentRecordScreen> {
  final _strengthsController = TextEditingController();
  final _difficultiesController = TextEditingController();
  final _supportsController = TextEditingController();
  bool _loadStarted = false;
  bool _profileLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<StudentRecordController>();
      await controller.load(widget.student);
      if (!mounted) return;
      final record = controller.record;
      _strengthsController.text = record?.strengths ?? '';
      _difficultiesController.text = record?.difficulties ?? '';
      _supportsController.text = record?.supports ?? '';
      setState(() => _profileLoaded = true);
    });
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
    final controller = context.watch<StudentRecordController>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.studentRecordTitle),
            Text(
              widget.student.displayName,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.isSaving ? null : () => _addEntry(context),
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(l10n.addRecordEntry),
      ),
      body: SafeArea(
        child: controller.isLoading || !_profileLoaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _EvidenceCard(controller: controller),
                          const SizedBox(height: 16),
                          _ProfileCard(
                            strengthsController: _strengthsController,
                            difficultiesController: _difficultiesController,
                            supportsController: _supportsController,
                            saving: controller.isSaving,
                            onSave: _saveProfile,
                          ),
                          if (controller.error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              l10n.profileSaveError,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Text(
                            l10n.recordTimeline,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          if (controller.entries.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(l10n.noRecordEntries),
                              ),
                            )
                          else
                            for (final entry in controller.entries) ...[
                              Card(
                                child: ListTile(
                                  leading: Icon(
                                    entry.kind ==
                                            StudentRecordEntryKind.observation
                                        ? Icons.visibility_outlined
                                        : Icons.handshake_outlined,
                                  ),
                                  title: Text(
                                    l10n.recordEntryKindLabel(entry.kind),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(entry.text),
                                  ),
                                  trailing: Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatMediumDate(entry.occurredAt.toLocal()),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    await context.read<StudentRecordController>().saveProfile(
      strengths: _strengthsController.text,
      difficulties: _difficultiesController.text,
      supports: _supportsController.text,
    );
  }

  Future<void> _addEntry(BuildContext context) async {
    final draft = await showDialog<_EntryDraft>(
      context: context,
      builder: (context) => const _EntryDialog(),
    );
    if (draft == null || !context.mounted) return;
    await context.read<StudentRecordController>().addEntry(
      kind: draft.kind,
      text: draft.text,
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.controller});

  final StudentRecordController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recordEvidence,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Chip(
                  label: Text(
                    '${l10n.totalEvidence}: ${controller.totalEvidence}',
                  ),
                ),
                Chip(
                  label: Text(
                    '${l10n.masteredEvidence}: ${controller.masteredEvidence}',
                  ),
                ),
                Chip(
                  label: Text(
                    '${l10n.requiresSupportEvidence}: ${controller.requiresSupportEvidence}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.strengthsController,
    required this.difficultiesController,
    required this.supportsController,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController strengthsController;
  final TextEditingController difficultiesController;
  final TextEditingController supportsController;
  final bool saving;
  final VoidCallback onSave;

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
              l10n.pedagogicalProfile,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final fields = <Widget>[
                  _ProfileField(
                    controller: strengthsController,
                    label: l10n.strengths,
                    icon: Icons.trending_up_rounded,
                  ),
                  _ProfileField(
                    controller: difficultiesController,
                    label: l10n.difficulties,
                    icon: Icons.flag_outlined,
                  ),
                  _ProfileField(
                    controller: supportsController,
                    label: l10n.supports,
                    icon: Icons.support_outlined,
                  ),
                ];
                if (!wide) {
                  return Column(
                    children: [
                      for (var index = 0; index < fields.length; index++) ...[
                        fields[index],
                        if (index < fields.length - 1)
                          const SizedBox(height: 12),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < fields.length; index++) ...[
                      Expanded(child: fields[index]),
                      if (index < fields.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: const Icon(Icons.save_outlined),
                label: Text(l10n.saveProfile),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        prefixIcon: Icon(icon),
      ),
    );
  }
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog();

  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  StudentRecordEntryKind _kind = StudentRecordEntryKind.observation;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.addRecordEntry),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<StudentRecordEntryKind>(
                showSelectedIcon: false,
                segments: [
                  for (final kind in StudentRecordEntryKind.values)
                    ButtonSegment(
                      value: kind,
                      label: Text(l10n.recordEntryKindLabel(kind)),
                    ),
                ],
                selected: <StudentRecordEntryKind>{_kind},
                onSelectionChanged: (selection) {
                  setState(() => _kind = selection.single);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _textController,
                autofocus: true,
                minLines: 3,
                maxLines: 7,
                decoration: InputDecoration(labelText: l10n.entryText),
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
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _EntryDraft(kind: _kind, text: _textController.text),
    );
  }
}

final class _EntryDraft {
  const _EntryDraft({required this.kind, required this.text});

  final StudentRecordEntryKind kind;
  final String text;
}
