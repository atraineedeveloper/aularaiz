import 'package:aularaiz/app/errors/friendly_error_message.dart';
import 'package:aularaiz/app/layout/responsive_layout.dart';
import 'package:aularaiz/domain/incident/incident_category.dart';
import 'package:aularaiz/domain/incident/incident_report.dart';
import 'package:aularaiz/domain/incident/incident_status.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/incidents/presentation/incident_localization.dart';
import 'package:aularaiz/features/incidents/presentation/incident_reports_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IncidentReportsScreen extends StatefulWidget {
  const IncidentReportsScreen({
    required this.schoolId,
    required this.schoolName,
    required this.groups,
    this.initialStudentId,
    this.initialGroupId,
    this.embedded = false,
    super.key,
  });

  final String schoolId;
  final String schoolName;
  final List<TeachingGroup> groups;
  final String? initialStudentId;
  final String? initialGroupId;
  final bool embedded;

  @override
  State<IncidentReportsScreen> createState() => _IncidentReportsScreenState();
}

class _IncidentReportsScreenState extends State<IncidentReportsScreen> {
  bool _loadStarted = false;
  bool _initialEditorOpened = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final controller = context.read<IncidentReportsController>();
      await controller.load(schoolId: widget.schoolId, groups: widget.groups);
      if (!mounted || _initialEditorOpened || widget.initialStudentId == null) {
        return;
      }
      _initialEditorOpened = true;
      await controller.ensureStudentOption(widget.initialStudentId!);
      if (!mounted) return;
      await _openEditor(
        controller,
        initialStudentId: widget.initialStudentId,
        initialGroupId: widget.initialGroupId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentReportsController>();
    final layout = ResponsiveLayoutInfo.of(context);
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(_t(context, 'Incidencias', 'Incidents'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.isLoading || controller.isSaving
            ? null
            : () => _openEditor(controller),
        icon: const Icon(Icons.add_rounded),
        label: Text(_t(context, 'Registrar incidencia', 'New incident')),
      ),
      body: SafeArea(
        top: !widget.embedded,
        child: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : controller.error != null && controller.reports.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.all(layout.pagePadding),
                  child: Text(
                    friendlyErrorMessage(
                      context,
                      controller.error,
                      fallback: _t(
                        context,
                        'No se pudieron cargar las incidencias.',
                        'Incidents could not be loaded.',
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      layout.pagePadding,
                      layout.pagePadding,
                      layout.pagePadding,
                      layout.pagePadding + 84,
                    ),
                    children: [
                      Text(
                        _t(context, 'Incidencias', 'Incidents'),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _t(
                          context,
                          'Registra los hechos y las acciones tomadas. La fecha y hora se completan automáticamente.',
                          'Record what happened and what you did. Date and time are filled in automatically.',
                        ),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _FilterChip(
                            label: _t(context, 'Todas', 'All'),
                            selected: controller.statusFilter == null,
                            onSelected: () => controller.setStatusFilter(null),
                          ),
                          for (final status in IncidentStatus.values)
                            _FilterChip(
                              label: incidentStatusLabel(context, status),
                              selected: controller.statusFilter == status,
                              onSelected: () =>
                                  controller.setStatusFilter(status),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (controller.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            friendlyErrorMessage(
                              context,
                              controller.error,
                              fallback: _t(
                                context,
                                'No se pudo guardar la incidencia.',
                                'Could not save the incident.',
                              ),
                            ),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (controller.visibleReports.isEmpty)
                        _EmptyIncidents(onAdd: () => _openEditor(controller))
                      else
                        for (final report in controller.visibleReports)
                          _IncidentCard(
                            report: report,
                            groupName: controller.groupName(report.groupId),
                            studentNames: [
                              for (final id in report.studentIds)
                                if (controller.studentName(id) != null)
                                  controller.studentName(id)!,
                            ],
                            onEdit: () =>
                                _openEditor(controller, report: report),
                          ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _openEditor(
    IncidentReportsController controller, {
    IncidentReport? report,
    String? initialStudentId,
    String? initialGroupId,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<IncidentReportsController>.value(
          value: controller,
          child: IncidentEditorScreen(
            schoolName: widget.schoolName,
            groups: widget.groups,
            report: report,
            initialStudentId: initialStudentId,
            initialGroupId: initialGroupId,
          ),
        ),
      ),
    );
  }
}

class IncidentEditorScreen extends StatefulWidget {
  const IncidentEditorScreen({
    required this.schoolName,
    required this.groups,
    this.report,
    this.initialStudentId,
    this.initialGroupId,
    super.key,
  });

  final String schoolName;
  final List<TeachingGroup> groups;
  final IncidentReport? report;
  final String? initialStudentId;
  final String? initialGroupId;

  @override
  State<IncidentEditorScreen> createState() => _IncidentEditorScreenState();
}

class _IncidentEditorScreenState extends State<IncidentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;
  late final TextEditingController _actionTaken;
  late final TextEditingController _followUp;
  late DateTime _occurredAt;
  late IncidentCategory _category;
  late IncidentStatus _status;
  late String? _groupId;
  late final Set<String> _studentIds;
  late bool _familyNotified;
  late bool _leadershipNotified;
  bool _showFollowUp = false;

  bool get _isEditing => widget.report != null;

  @override
  void initState() {
    super.initState();
    final report = widget.report;
    _description = TextEditingController(text: report?.description ?? '');
    _actionTaken = TextEditingController(text: report?.actionTaken ?? '');
    _followUp = TextEditingController(text: report?.followUpNote ?? '');
    _occurredAt = report?.occurredAt.toLocal() ?? DateTime.now();
    _category = report?.category ?? IncidentCategory.other;
    _status = report?.status ?? IncidentStatus.open;
    _groupId =
        report?.groupId ??
        widget.initialGroupId ??
        (widget.groups.isEmpty ? null : widget.groups.first.id);
    _studentIds = <String>{
      ...?report?.studentIds,
      if (widget.initialStudentId != null) widget.initialStudentId!,
    };
    _familyNotified = report?.familyNotified ?? false;
    _leadershipNotified = report?.leadershipNotified ?? false;
    _showFollowUp =
        report?.followUpNote != null ||
        (report?.status != null && report!.status != IncidentStatus.open) ||
        _familyNotified ||
        _leadershipNotified;
  }

  @override
  void dispose() {
    _description.dispose();
    _actionTaken.dispose();
    _followUp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<IncidentReportsController>();
    final layout = ResponsiveLayoutInfo.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? _t(context, 'Editar incidencia', 'Edit incident')
              : _t(context, 'Registrar incidencia', 'New incident'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(layout.pagePadding),
                children: [
                  Text(
                    widget.schoolName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickOccurredAt,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      '${localizations.formatMediumDate(_occurredAt)} · '
                      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(_occurredAt))}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<IncidentCategory>(
                    initialValue: _category,
                    decoration: InputDecoration(
                      labelText: _t(
                        context,
                        'Tipo de incidencia',
                        'Incident type',
                      ),
                    ),
                    items: [
                      for (final category in IncidentCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(incidentCategoryLabel(context, category)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  if (widget.groups.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _groupId,
                      decoration: InputDecoration(
                        labelText: _t(
                          context,
                          'Grupo relacionado',
                          'Related class',
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            _t(context, 'Toda la escuela', 'Whole school'),
                          ),
                        ),
                        for (final group in widget.groups)
                          DropdownMenuItem<String?>(
                            value: group.id,
                            child: Text(group.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _groupId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ParticipantsField(
                    studentIds: _studentIds,
                    studentNames: [
                      for (final id in _studentIds)
                        if (controller.studentName(id) != null)
                          controller.studentName(id)!,
                    ],
                    onChoose: _pickStudents,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    autofocus: !_isEditing,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _t(context, '¿Qué ocurrió?', 'What happened?'),
                      hintText: _t(
                        context,
                        'Describe los hechos de forma breve y objetiva.',
                        'Briefly describe what happened in factual terms.',
                      ),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? _t(
                            context,
                            'Describe la incidencia.',
                            'Add a description.',
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _actionTaken,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 800,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: _t(
                        context,
                        'Acción inmediata (opcional)',
                        'Immediate action (optional)',
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Card(
                    child: ExpansionTile(
                      initiallyExpanded: _showFollowUp,
                      onExpansionChanged: (value) =>
                          setState(() => _showFollowUp = value),
                      leading: const Icon(Icons.task_alt_rounded),
                      title: Text(_t(context, 'Seguimiento', 'Follow-up')),
                      subtitle: Text(
                        _t(
                          context,
                          'Estado, acuerdos y a quién se informó',
                          'Status, next steps and who was informed',
                        ),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        DropdownButtonFormField<IncidentStatus>(
                          initialValue: _status,
                          decoration: InputDecoration(
                            labelText: _t(context, 'Estado', 'Status'),
                          ),
                          items: [
                            for (final status in IncidentStatus.values)
                              DropdownMenuItem(
                                value: status,
                                child: Text(
                                  incidentStatusLabel(context, status),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _status = value);
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _followUp,
                          minLines: 2,
                          maxLines: 4,
                          maxLength: 800,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            labelText: _t(
                              context,
                              'Nota de seguimiento (opcional)',
                              'Follow-up note (optional)',
                            ),
                            alignLabelWithHint: true,
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _familyNotified,
                          onChanged: (value) =>
                              setState(() => _familyNotified = value ?? false),
                          title: Text(
                            _t(
                              context,
                              'Se informó a la familia',
                              'Family informed',
                            ),
                          ),
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _leadershipNotified,
                          onChanged: (value) => setState(
                            () => _leadershipNotified = value ?? false,
                          ),
                          title: Text(
                            _t(
                              context,
                              'Se informó a dirección',
                              'School leadership informed',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (controller.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      friendlyErrorMessage(
                        context,
                        controller.error,
                        fallback: _t(
                          context,
                          'No se pudo guardar.',
                          'Could not save.',
                        ),
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                layout.pagePadding,
                8,
                layout.pagePadding,
                12,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: controller.isSaving ? null : _save,
                  icon: controller.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _t(context, 'Guardar incidencia', 'Save incident'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickOccurredAt() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 1),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickStudents() async {
    final controller = context.read<IncidentReportsController>();
    final chosen = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _IncidentStudentPicker(
        options: controller.studentOptions,
        selectedIds: _studentIds,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _studentIds
        ..clear()
        ..addAll(chosen);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await context.read<IncidentReportsController>().saveReport(
      existing: widget.report,
      groupId: _groupId,
      occurredAt: _occurredAt,
      category: _category,
      description: _description.text,
      actionTaken: _actionTaken.text,
      followUpNote: _followUp.text,
      familyNotified: _familyNotified,
      leadershipNotified: _leadershipNotified,
      status: _status,
      studentIds: _studentIds.toList(),
    );
    if (!mounted || !saved) return;
    Navigator.of(context).pop();
  }
}

class _IncidentStudentPicker extends StatefulWidget {
  const _IncidentStudentPicker({
    required this.options,
    required this.selectedIds,
  });

  final List<IncidentStudentOption> options;
  final Set<String> selectedIds;

  @override
  State<_IncidentStudentPicker> createState() => _IncidentStudentPickerState();
}

class _IncidentStudentPickerState extends State<_IncidentStudentPicker> {
  late final TextEditingController _query = TextEditingController();
  late final Set<String> _selected = Set<String>.of(widget.selectedIds);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim().toLowerCase();
    final visible = widget.options
        .where(
          (option) =>
              option.student.displayName.toLowerCase().contains(query) ||
              option.groupName.toLowerCase().contains(query),
        )
        .toList(growable: false);
    final size = MediaQuery.sizeOf(context);
    return AlertDialog(
      title: Text(_t(context, 'Alumnos involucrados', 'Students involved')),
      content: SizedBox(
        width: size.width < 600 ? size.width - 48 : 520,
        height: size.height < 500 ? size.height * 0.38 : size.height * 0.55,
        child: Column(
          children: [
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: _t(context, 'Buscar alumno', 'Search students'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.options.isEmpty
                  ? Center(
                      child: Text(
                        _t(
                          context,
                          'No hay alumnos activos en los grupos de este ciclo.',
                          'There are no active students in this school year.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final option = visible[index];
                        final selected = _selected.contains(option.student.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (value) => setState(() {
                            if (value ?? false) {
                              _selected.add(option.student.id);
                            } else {
                              _selected.remove(option.student.id);
                            }
                          }),
                          title: Text(option.student.displayName),
                          subtitle:
                              option.groupName.isEmpty &&
                                  option.gradeLabel.isEmpty
                              ? null
                              : Text(
                                  [
                                    if (option.groupName.isNotEmpty)
                                      option.groupName,
                                    if (option.gradeLabel.isNotEmpty)
                                      option.gradeLabel,
                                  ].join(' · '),
                                ),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      },
                    ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _t(
                  context,
                  '${_selected.length} seleccionados',
                  '${_selected.length} selected',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_t(context, 'Cancelar', 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, Set<String>.of(_selected)),
          child: Text(_t(context, 'Listo', 'Done')),
        ),
      ],
    );
  }
}

class _ParticipantsField extends StatelessWidget {
  const _ParticipantsField({
    required this.studentIds,
    required this.studentNames,
    required this.onChoose,
  });

  final Set<String> studentIds;
  final List<String> studentNames;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onChoose,
    icon: const Icon(Icons.groups_outlined),
    label: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        studentIds.isEmpty
            ? _t(context, 'Sin alumno específico', 'No specific student')
            : studentNames.isEmpty
            ? _t(
                context,
                '${studentIds.length} alumno(s) seleccionado(s)',
                '${studentIds.length} student(s) selected',
              )
            : studentNames.take(3).join(', ') +
                  (studentNames.length > 3
                      ? ' +${studentNames.length - 3}'
                      : ''),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.report,
    required this.studentNames,
    required this.onEdit,
    this.groupName,
  });

  final IncidentReport report;
  final List<String> studentNames;
  final String? groupName;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(report.occurredAt.toLocal()),
    );
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Icon(_categoryIcon(report.category), size: 20),
                      Text(
                        incidentCategoryLabel(context, report.category),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (report.wasCorrected)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(_t(context, 'Editada', 'Edited')),
                        ),
                    ],
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(_statusIcon(report.status), size: 17),
                    label: Text(incidentStatusLabel(context, report.status)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${localizations.formatMediumDate(report.occurredAt.toLocal())} · $time'
                '${groupName == null ? '' : ' · $groupName'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                report.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              if (studentNames.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final name in studentNames.take(4))
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                        ),
                        label: Text(name),
                      ),
                    if (studentNames.length > 4)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('+${studentNames.length - 4}'),
                      ),
                  ],
                ),
              ],
              if (report.actionTaken != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_t(context, 'Acción', 'Action')}: ${report.actionTaken}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (report.followUpNote != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_t(context, 'Seguimiento', 'Follow-up')}: ${report.followUpNote}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(_t(context, 'Ver / editar', 'View / edit')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
  );
}

class _EmptyIncidents extends StatelessWidget {
  const _EmptyIncidents({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.fact_check_outlined, size: 42),
          const SizedBox(height: 10),
          Text(
            _t(
              context,
              'No hay incidencias en este filtro.',
              'No incidents in this filter.',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              _t(context, 'Registrar la primera', 'Record the first one'),
            ),
          ),
        ],
      ),
    ),
  );
}

IconData _categoryIcon(IncidentCategory category) => switch (category) {
  IncidentCategory.health => Icons.health_and_safety_outlined,
  IncidentCategory.accident => Icons.healing_outlined,
  IncidentCategory.coexistence => Icons.diversity_3_outlined,
  IncidentCategory.behavior => Icons.psychology_alt_outlined,
  IncidentCategory.property => Icons.home_repair_service_outlined,
  IncidentCategory.other => Icons.assignment_outlined,
};

IconData _statusIcon(IncidentStatus status) => switch (status) {
  IncidentStatus.open => Icons.radio_button_unchecked_rounded,
  IncidentStatus.followUp => Icons.pending_actions_rounded,
  IncidentStatus.closed => Icons.check_circle_outline_rounded,
};

String _t(BuildContext context, String spanish, String english) =>
    Localizations.localeOf(context).languageCode == 'en' ? english : spanish;
