import 'package:aularaiz/application/student_import/student_import_models.dart';
import 'package:aularaiz/features/student_import/presentation/student_import_controller.dart';
import 'package:aularaiz/features/student_import/presentation/student_import_localization.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudentImportScreen extends StatefulWidget {
  const StudentImportScreen({super.key});

  @override
  State<StudentImportScreen> createState() => _StudentImportScreenState();
}

class _StudentImportScreenState extends State<StudentImportScreen> {
  static const _fileTypes = XTypeGroup(
    label: 'CSV / XLSX',
    extensions: ['csv', 'xlsx'],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<StudentImportController>();
    final table = controller.table;
    final mapping = controller.mapping;
    final preview = controller.preview;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importStudentsTitle)),
      bottomNavigationBar: preview == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                child: FilledButton.icon(
                  onPressed: preview.canConfirm && !controller.isImporting
                      ? _confirmImport
                      : null,
                  icon: controller.isImporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.playlist_add_check_circle_outlined),
                  label: Text(
                    '${l10n.importConfirmButton} (${preview.readyCount})',
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.importStudentsTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(l10n.importStudentsDescription),
                  const SizedBox(height: 18),
                  _PrivacyNotice(message: l10n.importPrivacyNote),
                  const SizedBox(height: 16),
                  _FileCard(
                    table: table,
                    isReading: controller.isReading,
                    onSelect: controller.isImporting ? null : _pickFile,
                  ),
                  if (controller.isReading) ...[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (controller.formatProblem != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(
                      message: l10n.importFormatProblem(
                        controller.formatProblem!,
                      ),
                    ),
                  ] else if (controller.error != null && preview == null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: l10n.importFailed),
                  ],
                  if (table != null && mapping != null) ...[
                    const SizedBox(height: 20),
                    _MappingCard(
                      mapping: mapping,
                      duplicateColumns: controller.mappingHasDuplicateColumns,
                      enabled: !controller.isImporting && !controller.isReading,
                      onChanged: controller.setColumn,
                    ),
                    if (!controller.mappingReady) ...[
                      const SizedBox(height: 10),
                      _ErrorBanner(
                        message: controller.mappingHasDuplicateColumns
                            ? l10n.importDuplicateMapping
                            : l10n.importRequiredMapping,
                      ),
                    ],
                  ],
                  if (preview != null) ...[
                    const SizedBox(height: 20),
                    _PreviewSection(
                      preview: preview,
                      enabled: !controller.isImporting,
                      onIncludedChanged: controller.setIncluded,
                      onEdit: _editRow,
                    ),
                    if (controller.error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: l10n.importFailed),
                    ],
                    const SizedBox(height: 88),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final file = await openFile(acceptedTypeGroups: const [_fileTypes]);
    if (file == null || !mounted) return;

    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await context.read<StudentImportController>().loadFile(
        fileName: file.name,
        bytes: bytes,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).importFileUnreadable),
        ),
      );
    }
  }

  Future<void> _editRow(StudentImportPreviewRow row) async {
    final updated = await showDialog<StudentImportDraft>(
      context: context,
      builder: (context) => _EditImportRowDialog(draft: row.draft),
    );
    if (updated == null || !mounted) return;
    await context.read<StudentImportController>().updateDraft(updated);
  }

  Future<void> _confirmImport() async {
    final controller = context.read<StudentImportController>();
    final preview = controller.preview;
    if (preview == null || !preview.canConfirm) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importConfirmTitle),
        content: Text(l10n.importConfirmBody(preview.readyCount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.importConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await controller.confirmImport();
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.importFailed)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importSuccess(result.importedCount))),
    );
    Navigator.of(context).pop(true);
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.table,
    required this.isReading,
    required this.onSelect,
  });

  final StudentImportTable? table;
  final bool isReading;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 18,
          runSpacing: 14,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    table == null ? l10n.importSelectFile : table!.sourceName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(l10n.importFileHint),
                  if (table?.sheetName != null) ...[
                    const SizedBox(height: 6),
                    Text('${l10n.importSheet}: ${table!.sheetName}'),
                  ],
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: isReading ? null : onSelect,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(
                table == null ? l10n.importSelectFile : l10n.importChangeFile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MappingCard extends StatelessWidget {
  const _MappingCard({
    required this.mapping,
    required this.duplicateColumns,
    required this.enabled,
    required this.onChanged,
  });

  final StudentImportMapping mapping;
  final bool duplicateColumns;
  final bool enabled;
  final Future<void> Function(StudentImportField field, int? column) onChanged;

  static const _requiredFields = {
    StudentImportField.givenNames,
    StudentImportField.firstSurname,
    StudentImportField.grade,
    StudentImportField.listNumber,
  };

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
              l10n.importMappingTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(l10n.importMappingDescription),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final field in StudentImportField.values)
                  SizedBox(
                    width: 320,
                    child: _MappingDropdown(
                      field: field,
                      requiredField: _requiredFields.contains(field),
                      mapping: mapping,
                      enabled: enabled,
                      onChanged: onChanged,
                    ),
                  ),
              ],
            ),
            if (duplicateColumns) ...[
              const SizedBox(height: 12),
              Text(
                l10n.importDuplicateMapping,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MappingDropdown extends StatelessWidget {
  const _MappingDropdown({
    required this.field,
    required this.requiredField,
    required this.mapping,
    required this.enabled,
    required this.onChanged,
  });

  final StudentImportField field;
  final bool requiredField;
  final StudentImportMapping mapping;
  final bool enabled;
  final Future<void> Function(StudentImportField field, int? column) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = mapping.columnFor(field) ?? -1;
    return DropdownButtonFormField<int>(
      key: ValueKey('${field.name}-$selected-${mapping.headers.length}'),
      initialValue: selected,
      decoration: InputDecoration(
        labelText:
            '${l10n.importFieldLabel(field)}${requiredField ? ' *' : ''}',
      ),
      items: [
        DropdownMenuItem(value: -1, child: Text(l10n.importNotMapped)),
        for (var index = 0; index < mapping.headers.length; index++)
          DropdownMenuItem(value: index, child: Text(mapping.headers[index])),
      ],
      onChanged: !enabled
          ? null
          : (value) => onChanged(field, value == -1 ? null : value),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.preview,
    required this.enabled,
    required this.onIncludedChanged,
    required this.onEdit,
  });

  final StudentImportPreview preview;
  final bool enabled;
  final Future<void> Function(int sourceRow, bool included) onIncludedChanged;
  final ValueChanged<StudentImportPreviewRow> onEdit;

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
              l10n.importPreviewTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 5),
            Text(l10n.importPreviewDescription),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _StatChip(
                  label: l10n.importIncluded,
                  value: preview.includedCount,
                ),
                _StatChip(label: l10n.importReady, value: preview.readyCount),
                _StatChip(label: l10n.importErrors, value: preview.errorCount),
                _StatChip(
                  label: l10n.importWarnings,
                  value: preview.warningCount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (preview.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(l10n.importNoRows, textAlign: TextAlign.center),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: preview.rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = preview.rows[index];
                  return _PreviewRowCard(
                    row: row,
                    enabled: enabled,
                    onIncludedChanged: (included) =>
                        onIncludedChanged(row.draft.sourceRow, included),
                    onEdit: () => onEdit(row),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _PreviewRowCard extends StatelessWidget {
  const _PreviewRowCard({
    required this.row,
    required this.enabled,
    required this.onIncludedChanged,
    required this.onEdit,
  });

  final StudentImportPreviewRow row;
  final bool enabled;
  final ValueChanged<bool> onIncludedChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final draft = row.draft;
    final title = [
      draft.givenNames.trim(),
      draft.firstSurname.trim(),
      draft.secondSurname.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    final colors = Theme.of(context).colorScheme;

    return Opacity(
      opacity: draft.included ? 1 : 0.62,
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: draft.included,
                onChanged: !enabled
                    ? null
                    : (value) => onIncludedChanged(value ?? false),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? '—' : title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${l10n.importRow} ${draft.sourceRow} · '
                      '${l10n.importFieldLabel(StudentImportField.listNumber)}: '
                      '${draft.listNumberText.isEmpty ? '—' : draft.listNumberText} · '
                      '${l10n.importFieldLabel(StudentImportField.grade)}: '
                      '${draft.gradeText.isEmpty ? '—' : draft.gradeText}',
                    ),
                    if (draft.sexText.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${l10n.importFieldLabel(StudentImportField.sex)}: '
                        '${draft.sexText}',
                      ),
                    ],
                    if (draft.birthDateText.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${l10n.importFieldLabel(StudentImportField.birthDate)}: '
                        '${draft.birthDateText}',
                      ),
                    ],
                    if (row.issues.isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final issue in row.issues)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    issue.severity ==
                                        StudentImportIssueSeverity.error
                                    ? colors.errorContainer
                                    : colors.tertiaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.importIssueLabel(issue),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color:
                                          issue.severity ==
                                              StudentImportIssueSeverity.error
                                          ? colors.onErrorContainer
                                          : colors.onTertiaryContainer,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.importEditRow,
                onPressed: enabled ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditImportRowDialog extends StatefulWidget {
  const _EditImportRowDialog({required this.draft});

  final StudentImportDraft draft;

  @override
  State<_EditImportRowDialog> createState() => _EditImportRowDialogState();
}

class _EditImportRowDialogState extends State<_EditImportRowDialog> {
  late final TextEditingController _givenNames;
  late final TextEditingController _firstSurname;
  late final TextEditingController _secondSurname;
  late final TextEditingController _sex;
  late final TextEditingController _birthDate;
  late final TextEditingController _grade;
  late final TextEditingController _listNumber;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _givenNames = TextEditingController(text: draft.givenNames);
    _firstSurname = TextEditingController(text: draft.firstSurname);
    _secondSurname = TextEditingController(text: draft.secondSurname);
    _sex = TextEditingController(text: draft.sexText);
    _birthDate = TextEditingController(text: draft.birthDateText);
    _grade = TextEditingController(text: draft.gradeText);
    _listNumber = TextEditingController(text: draft.listNumberText);
  }

  @override
  void dispose() {
    _givenNames.dispose();
    _firstSurname.dispose();
    _secondSurname.dispose();
    _sex.dispose();
    _birthDate.dispose();
    _grade.dispose();
    _listNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text('${l10n.importEditRow} ${widget.draft.sourceRow}'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _givenNames,
                decoration: InputDecoration(
                  labelText: l10n.importFieldLabel(
                    StudentImportField.givenNames,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _firstSurname,
                decoration: InputDecoration(
                  labelText: l10n.importFieldLabel(
                    StudentImportField.firstSurname,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _secondSurname,
                decoration: InputDecoration(
                  labelText: l10n.importFieldLabel(
                    StudentImportField.secondSurname,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sex,
                decoration: InputDecoration(
                  labelText: l10n.importFieldLabel(StudentImportField.sex),
                  hintText: 'Masculino / Femenino',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _birthDate,
                decoration: InputDecoration(
                  labelText: l10n.importFieldLabel(
                    StudentImportField.birthDate,
                  ),
                  hintText: 'DD/MM/AAAA',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _grade,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.importFieldLabel(StudentImportField.grade),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _listNumber,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.importFieldLabel(
                    StudentImportField.listNumber,
                  ),
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
          onPressed: () {
            Navigator.of(context).pop(
              widget.draft.copyWith(
                givenNames: _givenNames.text,
                firstSurname: _firstSurname.text,
                secondSurname: _secondSurname.text,
                sexText: _sex.text,
                birthDateText: _birthDate.text,
                gradeText: _grade.text,
                listNumberText: _listNumber.text,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
