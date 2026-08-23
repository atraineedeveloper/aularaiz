import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/articulating_axis.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/projects/presentation/projects_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    required this.group,
    required this.onEvaluateActivity,
    super.key,
  });

  final TeachingGroup group;
  final ValueChanged<Activity> onEvaluateActivity;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadStarted) {
      _loadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ProjectsController>().load(widget.group);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<ProjectsController>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.projectsTitle),
            Text(
              widget.group.name,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.isSaving ? null : () => _createProject(context),
        icon: const Icon(Icons.add_task_rounded),
        label: Text(l10n.createProject),
      ),
      body: SafeArea(
        child: controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (controller.error != null) ...[
                            Text(
                              l10n.projectSaveError,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (controller.projects.isEmpty)
                            _ProjectsEmpty(message: l10n.projectsEmpty)
                          else
                            for (final project in controller.projects) ...[
                              _ProjectCard(
                                project: project,
                                activities: controller.activitiesFor(
                                  project.id,
                                ),
                                isSaving: controller.isSaving,
                                onLifecycleChanged: (lifecycle) {
                                  controller.setLifecycle(project, lifecycle);
                                },
                                onAddActivity: () {
                                  _createActivity(context, project);
                                },
                                onEvaluateActivity: widget.onEvaluateActivity,
                              ),
                              const SizedBox(height: 14),
                            ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final draft = await showDialog<_ProjectDraft>(
      context: context,
      builder: (context) => _ProjectDialog(group: widget.group),
    );
    if (draft == null || !context.mounted) return;
    await context.read<ProjectsController>().createProject(
      title: draft.title,
      methodology: draft.methodology,
      formativeFields: draft.formativeFields,
      articulatingAxes: draft.articulatingAxes,
      targetGrades: draft.targetGrades,
    );
  }

  Future<void> _createActivity(BuildContext context, Project project) async {
    final draft = await showDialog<_ActivityDraft>(
      context: context,
      builder: (context) => _ActivityDialog(project: project),
    );
    if (draft == null || !context.mounted) return;
    await context.read<ProjectsController>().createActivity(
      project: project,
      title: draft.title,
      formativeField: draft.formativeField,
      targetGrades: draft.targetGrades,
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.activities,
    required this.isSaving,
    required this.onLifecycleChanged,
    required this.onAddActivity,
    required this.onEvaluateActivity,
  });

  final Project project;
  final List<Activity> activities;
  final bool isSaving;
  final ValueChanged<ProjectLifecycle> onLifecycleChanged;
  final VoidCallback onAddActivity;
  final ValueChanged<Activity> onEvaluateActivity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grades = project.targetGrades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));
    final fields = project.formativeFields.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    final axes = project.articulatingAxes.toList()
      ..sort((left, right) => left.index.compareTo(right.index));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  project.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SegmentedButton<ProjectLifecycle>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ProjectLifecycle.draft,
                      label: Text(l10n.projectDraft),
                    ),
                    ButtonSegment(
                      value: ProjectLifecycle.inProgress,
                      label: Text(l10n.projectInProgress),
                    ),
                    ButtonSegment(
                      value: ProjectLifecycle.completed,
                      label: Text(l10n.projectCompleted),
                    ),
                  ],
                  selected: <ProjectLifecycle>{project.lifecycle},
                  onSelectionChanged: isSaving
                      ? null
                      : (selection) => onLifecycleChanged(selection.single),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _methodologyLabel(project.methodology, l10n),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in fields)
                  Chip(
                    avatar: const Icon(Icons.category_outlined, size: 18),
                    label: Text(_fieldLabel(field, l10n)),
                  ),
                for (final grade in grades)
                  Chip(label: Text(_gradeLabel(grade, l10n))),
              ],
            ),
            if (axes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.articulatingAxes,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final axis in axes)
                    Chip(
                      avatar: const Icon(Icons.hub_outlined, size: 18),
                      label: Text(_axisLabel(axis, l10n)),
                    ),
                ],
              ),
            ],
            const Divider(height: 30),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.activitiesTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: isSaving ? null : onAddActivity,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.addActivity),
                ),
              ],
            ),
            if (activities.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(l10n.activitiesEmpty),
              )
            else
              for (final activity in activities)
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        const Icon(Icons.assignment_outlined),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 220),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                activity.title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_fieldLabel(activity.formativeField, l10n)} · ${l10n.activityRosterCount(activity.roster.length)}',
                              ),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => onEvaluateActivity(activity),
                          icon: const Icon(Icons.assignment_turned_in_outlined),
                          label: Text(l10n.evaluateActivity),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ProjectsEmpty extends StatelessWidget {
  const _ProjectsEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_motion_outlined,
              size: 58,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProjectDialog extends StatefulWidget {
  const _ProjectDialog({required this.group});

  final TeachingGroup group;

  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  ProjectMethodology _methodology = ProjectMethodology.communityProjects;
  final Set<FormativeField> _fields = <FormativeField>{};
  final Set<ArticulatingAxis> _axes = <ArticulatingAxis>{};
  final Set<PrimaryGrade> _grades = <PrimaryGrade>{};
  bool _fieldsError = false;
  bool _gradesError = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final availableGrades = widget.group.grades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));
    final fields = FormativeField.values
        .where((value) => value != FormativeField.unspecified)
        .toList(growable: false);

    return AlertDialog(
      title: Text(l10n.createProject),
      content: SizedBox(
        width: 680,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.projectTitle),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ProjectMethodology>(
                  initialValue: _methodology,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.methodology),
                  items: [
                    for (final value in ProjectMethodology.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          _methodologyLabel(value, l10n),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _methodology = value);
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.formativeFields,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final field in fields)
                      FilterChip(
                        label: Text(_fieldLabel(field, l10n)),
                        selected: _fields.contains(field),
                        onSelected: (selected) {
                          setState(() {
                            selected
                                ? _fields.add(field)
                                : _fields.remove(field);
                            _fieldsError = false;
                          });
                        },
                      ),
                  ],
                ),
                if (_fieldsError) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.selectAtLeastOneField,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  l10n.articulatingAxes,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.articulatingAxesHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final axis in ArticulatingAxis.values)
                      FilterChip(
                        label: Text(_axisLabel(axis, l10n)),
                        selected: _axes.contains(axis),
                        onSelected: (selected) {
                          setState(() {
                            selected ? _axes.add(axis) : _axes.remove(axis);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.grades,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final grade in availableGrades)
                      FilterChip(
                        label: Text(_gradeLabel(grade, l10n)),
                        selected: _grades.contains(grade),
                        onSelected: (selected) {
                          setState(() {
                            selected
                                ? _grades.add(grade)
                                : _grades.remove(grade);
                            _gradesError = false;
                          });
                        },
                      ),
                  ],
                ),
                if (_gradesError) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.selectAtLeastOneGrade,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.create)),
      ],
    );
  }

  void _submit() {
    final hasFields = _fields.isNotEmpty;
    final hasGrades = _grades.isNotEmpty;
    setState(() {
      _fieldsError = !hasFields;
      _gradesError = !hasGrades;
    });
    if (!_formKey.currentState!.validate() || !hasFields || !hasGrades) return;
    Navigator.of(context).pop(
      _ProjectDraft(
        title: _titleController.text.trim(),
        methodology: _methodology,
        formativeFields: Set<FormativeField>.of(_fields),
        articulatingAxes: Set<ArticulatingAxis>.of(_axes),
        targetGrades: Set<PrimaryGrade>.of(_grades),
      ),
    );
  }
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({required this.project});

  final Project project;

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final Set<PrimaryGrade> _grades = <PrimaryGrade>{};
  late FormativeField _field;
  bool _gradesError = false;

  @override
  void initState() {
    super.initState();
    final fields = widget.project.formativeFields.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    _field = fields.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final availableGrades = widget.project.targetGrades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));
    final availableFields = widget.project.formativeFields.toList()
      ..sort((left, right) => left.index.compareTo(right.index));

    return AlertDialog(
      title: Text(l10n.addActivity),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.activityTitle),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<FormativeField>(
                  initialValue: _field,
                  decoration: InputDecoration(
                    labelText: l10n.activityFormativeField,
                  ),
                  items: [
                    for (final field in availableFields)
                      DropdownMenuItem(
                        value: field,
                        child: Text(_fieldLabel(field, l10n)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _field = value);
                  },
                ),
                const SizedBox(height: 18),
                Text(l10n.activityGradeScope),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final grade in availableGrades)
                      FilterChip(
                        label: Text(_gradeLabel(grade, l10n)),
                        selected: _grades.contains(grade),
                        onSelected: (selected) {
                          setState(() {
                            selected
                                ? _grades.add(grade)
                                : _grades.remove(grade);
                            _gradesError = false;
                          });
                        },
                      ),
                  ],
                ),
                if (_gradesError) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.selectAtLeastOneGrade,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  l10n.activityRosterSnapshotHelp,
                  style: Theme.of(context).textTheme.bodySmall,
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
        FilledButton(onPressed: _submit, child: Text(l10n.create)),
      ],
    );
  }

  void _submit() {
    final hasGrades = _grades.isNotEmpty;
    setState(() => _gradesError = !hasGrades);
    if (!_formKey.currentState!.validate() || !hasGrades) return;
    Navigator.of(context).pop(
      _ActivityDraft(
        title: _titleController.text.trim(),
        formativeField: _field,
        targetGrades: Set<PrimaryGrade>.of(_grades),
      ),
    );
  }
}

final class _ProjectDraft {
  const _ProjectDraft({
    required this.title,
    required this.methodology,
    required this.formativeFields,
    required this.articulatingAxes,
    required this.targetGrades,
  });

  final String title;
  final ProjectMethodology methodology;
  final Set<FormativeField> formativeFields;
  final Set<ArticulatingAxis> articulatingAxes;
  final Set<PrimaryGrade> targetGrades;
}

final class _ActivityDraft {
  const _ActivityDraft({
    required this.title,
    required this.formativeField,
    required this.targetGrades,
  });

  final String title;
  final FormativeField formativeField;
  final Set<PrimaryGrade> targetGrades;
}

String _gradeLabel(PrimaryGrade grade, AppLocalizations l10n) =>
    switch (grade) {
      PrimaryGrade.first => l10n.grade1,
      PrimaryGrade.second => l10n.grade2,
      PrimaryGrade.third => l10n.grade3,
      PrimaryGrade.fourth => l10n.grade4,
      PrimaryGrade.fifth => l10n.grade5,
      PrimaryGrade.sixth => l10n.grade6,
    };

String _methodologyLabel(
  ProjectMethodology methodology,
  AppLocalizations l10n,
) => switch (methodology) {
  ProjectMethodology.unspecified => l10n.methodologyUnspecified,
  ProjectMethodology.communityProjects => l10n.methodologyCommunityProjects,
  ProjectMethodology.inquirySteam => l10n.methodologyInquirySteam,
  ProjectMethodology.problemBasedLearning => l10n.methodologyProblemBased,
  ProjectMethodology.serviceLearning => l10n.methodologyServiceLearning,
};

String _fieldLabel(FormativeField field, AppLocalizations l10n) =>
    switch (field) {
      FormativeField.unspecified => l10n.formativeFieldUnspecified,
      FormativeField.languages => l10n.formativeFieldLanguages,
      FormativeField.knowledgeAndScientificThought =>
        l10n.formativeFieldScientificThought,
      FormativeField.ethicsNatureAndSocieties =>
        l10n.formativeFieldEthicsNature,
      FormativeField.humanAndCommunity => l10n.formativeFieldHumanCommunity,
    };

String _axisLabel(ArticulatingAxis axis, AppLocalizations l10n) =>
    switch (axis) {
      ArticulatingAxis.inclusion => l10n.axisInclusion,
      ArticulatingAxis.criticalThinking => l10n.axisCriticalThinking,
      ArticulatingAxis.criticalInterculturality =>
        l10n.axisCriticalInterculturality,
      ArticulatingAxis.genderEquality => l10n.axisGenderEquality,
      ArticulatingAxis.healthyLife => l10n.axisHealthyLife,
      ArticulatingAxis.culturesThroughReadingAndWriting =>
        l10n.axisCulturesReadingWriting,
      ArticulatingAxis.artsAndAestheticExperiences => l10n.axisArtsAesthetic,
    };
