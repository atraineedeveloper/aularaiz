import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/student_roster/presentation/student_roster_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudentRosterScreen extends StatefulWidget {
  const StudentRosterScreen({required this.group, super.key});

  final TeachingGroup group;

  @override
  State<StudentRosterScreen> createState() => _StudentRosterScreenState();
}

class _StudentRosterScreenState extends State<StudentRosterScreen> {
  final _searchController = TextEditingController();
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      context.read<StudentRosterController>().load(widget.group);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<StudentRosterController>();
    final entries = controller.entries;

    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.isSaving ? null : () => _addStudent(context),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l10n.addStudent),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.studentsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: controller.setQuery,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.searchStudents,
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            controller.setQuery('');
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.studentSaveError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : entries.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.trim().isEmpty
                              ? l10n.studentsEmpty
                              : l10n.noSearchResults,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _StudentTile(
                            entry: entries[index],
                            onEdit: () => _editStudent(context, entries[index]),
                            onDeactivate: () => _deactivate(
                              context,
                              entries[index],
                            ),
                            onReactivate: () => _reactivate(
                              context,
                              entries[index],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addStudent(BuildContext context) async {
    final draft = await showDialog<_StudentDraft>(
      context: context,
      builder: (context) => _StudentDialog(group: widget.group),
    );
    if (draft == null || !mounted) return;

    await context.read<StudentRosterController>().createStudent(
      givenNames: draft.givenNames,
      firstSurname: draft.firstSurname,
      secondSurname: draft.secondSurname,
      birthDate: draft.birthDate,
      grade: draft.grade,
      listNumber: draft.listNumber,
    );
  }

  Future<void> _editStudent(
    BuildContext context,
    StudentRosterEntry entry,
  ) async {
    final draft = await showDialog<_StudentDraft>(
      context: context,
      builder: (context) => _StudentDialog(
        group: widget.group,
        entry: entry,
        identityOnly: true,
      ),
    );
    if (draft == null || !mounted) return;

    await context.read<StudentRosterController>().updateStudent(
      entry: entry,
      givenNames: draft.givenNames,
      firstSurname: draft.firstSurname,
      secondSurname: draft.secondSurname,
      birthDate: draft.birthDate,
    );
  }

  Future<void> _deactivate(
    BuildContext context,
    StudentRosterEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.deactivateStudent),
          content: Text(entry.student.displayName),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.deactivateStudent),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    await context.read<StudentRosterController>().deactivate(
      entry,
      DateTime.now(),
    );
  }

  Future<void> _reactivate(
    BuildContext context,
    StudentRosterEntry entry,
  ) async {
    final draft = await showDialog<_EnrollmentDraft>(
      context: context,
      builder: (context) => _ReactivateDialog(
        group: widget.group,
        entry: entry,
      ),
    );
    if (draft == null || !mounted) return;

    await context.read<StudentRosterController>().reactivate(
      entry: entry,
      grade: draft.grade,
      listNumber: draft.listNumber,
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.entry,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
  });

  final StudentRosterEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${entry.enrollment.listNumber}')),
        title: Text(entry.student.displayName),
        subtitle: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(_gradeLabel(entry.enrollment.grade, l10n)),
            Text(entry.isActive ? l10n.active : l10n.inactive),
          ],
        ),
        trailing: PopupMenuButton<_StudentAction>(
          onSelected: (action) {
            switch (action) {
              case _StudentAction.edit:
                onEdit();
              case _StudentAction.deactivate:
                onDeactivate();
              case _StudentAction.reactivate:
                onReactivate();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _StudentAction.edit,
              child: Text(l10n.editStudent),
            ),
            if (entry.isActive)
              PopupMenuItem(
                value: _StudentAction.deactivate,
                child: Text(l10n.deactivateStudent),
              )
            else
              PopupMenuItem(
                value: _StudentAction.reactivate,
                child: Text(l10n.reactivateStudent),
              ),
          ],
        ),
      ),
    );
  }
}

enum _StudentAction { edit, deactivate, reactivate }

class _StudentDialog extends StatefulWidget {
  const _StudentDialog({
    required this.group,
    this.entry,
    this.identityOnly = false,
  });

  final TeachingGroup group;
  final StudentRosterEntry? entry;
  final bool identityOnly;

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _givenNamesController;
  late final TextEditingController _firstSurnameController;
  late final TextEditingController _secondSurnameController;
  late final TextEditingController _listNumberController;
  late PrimaryGrade _grade;
  DateTime? _birthDate;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final grades = widget.group.grades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));
    _givenNamesController = TextEditingController(text: entry?.student.givenNames);
    _firstSurnameController = TextEditingController(
      text: entry?.student.firstSurname,
    );
    _secondSurnameController = TextEditingController(
      text: entry?.student.secondSurname,
    );
    _listNumberController = TextEditingController(
      text: entry?.enrollment.listNumber.toString(),
    );
    _grade = entry?.enrollment.grade ?? grades.first;
    _birthDate = entry?.student.birthDate;
  }

  @override
  void dispose() {
    _givenNamesController.dispose();
    _firstSurnameController.dispose();
    _secondSurnameController.dispose();
    _listNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grades = widget.group.grades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_dirty) return;
        final discard = await _confirmDiscard(context);
        if (discard && context.mounted) Navigator.of(context).pop();
      },
      child: AlertDialog(
        title: Text(widget.entry == null ? l10n.addStudent : l10n.editStudent),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _formKey,
            onChanged: () => _dirty = true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _givenNamesController,
                    autofocus: true,
                    decoration: InputDecoration(labelText: l10n.givenNames),
                    validator: (value) => _required(value, l10n),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstSurnameController,
                    decoration: InputDecoration(labelText: l10n.firstSurname),
                    validator: (value) => _required(value, l10n),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secondSurnameController,
                    decoration: InputDecoration(labelText: l10n.secondSurname),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _selectBirthDate,
                    icon: const Icon(Icons.cake_outlined),
                    label: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _birthDate == null
                            ? l10n.birthDateOptional
                            : MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(_birthDate!),
                      ),
                    ),
                  ),
                  if (!widget.identityOnly) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<PrimaryGrade>(
                      initialValue: _grade,
                      decoration: InputDecoration(labelText: l10n.grade),
                      items: [
                        for (final grade in grades)
                          DropdownMenuItem(
                            value: grade,
                            child: Text(_gradeLabel(grade, l10n)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _grade = value;
                            _dirty = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _listNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: l10n.listNumber),
                      validator: (value) {
                        final number = int.tryParse(value?.trim() ?? '');
                        return number == null || number <= 0
                            ? l10n.invalidListNumber
                            : null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
          FilledButton(onPressed: _submit, child: Text(l10n.save)),
        ],
      ),
    );
  }

  String? _required(String? value, AppLocalizations l10n) {
    return value == null || value.trim().isEmpty ? l10n.requiredField : null;
  }

  Future<void> _selectBirthDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2018),
      firstDate: DateTime(2005),
      lastDate: DateTime.now(),
    );
    if (selected != null) {
      setState(() {
        _birthDate = selected;
        _dirty = true;
      });
    }
  }

  Future<void> _cancel() async {
    if (!_dirty || await _confirmDiscard(context)) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.cancel),
            content: Text(l10n.setupSubtitle),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.back),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.entry;
    final listNumber = widget.identityOnly
        ? existing!.enrollment.listNumber
        : int.parse(_listNumberController.text.trim());
    final grade = widget.identityOnly ? existing!.enrollment.grade : _grade;

    _dirty = false;
    Navigator.of(context).pop(
      _StudentDraft(
        givenNames: _givenNamesController.text,
        firstSurname: _firstSurnameController.text,
        secondSurname: _secondSurnameController.text,
        birthDate: _birthDate,
        grade: grade,
        listNumber: listNumber,
      ),
    );
  }
}

class _ReactivateDialog extends StatefulWidget {
  const _ReactivateDialog({required this.group, required this.entry});

  final TeachingGroup group;
  final StudentRosterEntry entry;

  @override
  State<_ReactivateDialog> createState() => _ReactivateDialogState();
}

class _ReactivateDialogState extends State<_ReactivateDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _listNumberController;
  late PrimaryGrade _grade;

  @override
  void initState() {
    super.initState();
    final grades = widget.group.grades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));
    _grade = widget.group.grades.contains(widget.entry.enrollment.grade)
        ? widget.entry.enrollment.grade
        : grades.first;
    _listNumberController = TextEditingController(
      text: widget.entry.enrollment.listNumber.toString(),
    );
  }

  @override
  void dispose() {
    _listNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grades = widget.group.grades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));

    return AlertDialog(
      title: Text(l10n.reactivateStudent),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<PrimaryGrade>(
              initialValue: _grade,
              decoration: InputDecoration(labelText: l10n.grade),
              items: [
                for (final grade in grades)
                  DropdownMenuItem(
                    value: grade,
                    child: Text(_gradeLabel(grade, l10n)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _grade = value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _listNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.listNumber),
              validator: (value) {
                final number = int.tryParse(value?.trim() ?? '');
                return number == null || number <= 0
                    ? l10n.invalidListNumber
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.reactivateStudent)),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _EnrollmentDraft(
        grade: _grade,
        listNumber: int.parse(_listNumberController.text.trim()),
      ),
    );
  }
}

final class _StudentDraft {
  const _StudentDraft({
    required this.givenNames,
    required this.firstSurname,
    required this.secondSurname,
    required this.birthDate,
    required this.grade,
    required this.listNumber,
  });

  final String givenNames;
  final String firstSurname;
  final String secondSurname;
  final DateTime? birthDate;
  final PrimaryGrade grade;
  final int listNumber;
}

final class _EnrollmentDraft {
  const _EnrollmentDraft({required this.grade, required this.listNumber});

  final PrimaryGrade grade;
  final int listNumber;
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
