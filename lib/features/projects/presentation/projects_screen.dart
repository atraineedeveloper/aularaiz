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
  const ProjectsScreen({required this.group, required this.onEvaluateActivity, super.key});
  final TeachingGroup group;
  final ValueChanged<Activity> onEvaluateActivity;
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _loaded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProjectsController>().load(widget.group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<ProjectsController>();
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l10n.projectsTitle), Text(widget.group.name, style: Theme.of(context).textTheme.bodySmall)])),
      floatingActionButton: FloatingActionButton.extended(onPressed: controller.isSaving ? null : () => _createProject(context), icon: const Icon(Icons.add_task_rounded), label: Text(l10n.createProject)),
      body: SafeArea(child: controller.isLoading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        children: [Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1080), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (controller.error != null) ...[Text(l10n.projectSaveError, style: TextStyle(color: Theme.of(context).colorScheme.error)), const SizedBox(height: 12)],
          if (controller.projects.isEmpty)
            Card(child: Padding(padding: const EdgeInsets.all(32), child: Text(l10n.projectsEmpty, textAlign: TextAlign.center)))
          else
            for (final project in controller.projects) ...[
              _ProjectCard(project: project, activities: controller.activitiesFor(project.id), isSaving: controller.isSaving, onLifecycleChanged: (v) => controller.setLifecycle(project, v), onAddActivity: () => _createActivity(context, project), onEvaluateActivity: widget.onEvaluateActivity),
              const SizedBox(height: 14),
            ],
        ])))],
      )),
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final draft = await showDialog<_ProjectDraft>(context: context, builder: (_) => _ProjectDialog(group: widget.group));
    if (draft == null || !context.mounted) return;
    await context.read<ProjectsController>().createProject(title: draft.title, methodology: draft.methodology, articulatingAxes: draft.axes, targetGrades: draft.grades);
  }

  Future<void> _createActivity(BuildContext context, Project project) async {
    final draft = await showDialog<_ActivityDraft>(context: context, builder: (_) => _ActivityDialog(project: project));
    if (draft == null || !context.mounted) return;
    await context.read<ProjectsController>().createActivity(project: project, title: draft.title, formativeField: draft.field, targetGrades: draft.grades, occursOn: draft.date);
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, required this.activities, required this.isSaving, required this.onLifecycleChanged, required this.onAddActivity, required this.onEvaluateActivity});
  final Project project;
  final List<Activity> activities;
  final bool isSaving;
  final ValueChanged<ProjectLifecycle> onLifecycleChanged;
  final VoidCallback onAddActivity;
  final ValueChanged<Activity> onEvaluateActivity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grades = project.targetGrades.toList()..sort((a, b) => a.number.compareTo(b.number));
    final axes = project.articulatingAxes.toList()..sort((a, b) => a.index.compareTo(b.index));
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 16, runSpacing: 12, children: [
        Text(project.title, style: Theme.of(context).textTheme.titleLarge),
        SegmentedButton<ProjectLifecycle>(showSelectedIcon: false, segments: [ButtonSegment(value: ProjectLifecycle.draft, label: Text(l10n.projectDraft)), ButtonSegment(value: ProjectLifecycle.inProgress, label: Text(l10n.projectInProgress)), ButtonSegment(value: ProjectLifecycle.completed, label: Text(l10n.projectCompleted))], selected: {project.lifecycle}, onSelectionChanged: isSaving ? null : (v) => onLifecycleChanged(v.single)),
      ]),
      const SizedBox(height: 12),
      Text(_methodologyLabel(project.methodology, l10n), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final grade in grades) Chip(label: Text(_gradeLabel(grade, l10n))), for (final axis in axes) Chip(avatar: const Icon(Icons.hub_outlined, size: 18), label: Text(_axisLabel(axis, l10n)))]),
      const Divider(height: 30),
      Row(children: [Expanded(child: Text(l10n.activitiesTitle, style: Theme.of(context).textTheme.titleMedium)), TextButton.icon(onPressed: isSaving ? null : onAddActivity, icon: const Icon(Icons.add_rounded), label: Text(l10n.addActivity))]),
      if (activities.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(l10n.activitiesEmpty)) else for (final activity in activities)
        Card.outlined(child: Padding(padding: const EdgeInsets.all(12), child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
          CircleAvatar(radius: 22, child: Text(activity.displayIdentifier)),
          ConstrainedBox(constraints: const BoxConstraints(minWidth: 260), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(activity.title, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 4), Text('${_dateLabel(context, activity.occursOn)} · ${_fieldLabel(activity.formativeField, l10n)}'), Text(l10n.activityRosterCount(activity.roster.length), style: Theme.of(context).textTheme.bodySmall)])),
          FilledButton.tonalIcon(onPressed: () => onEvaluateActivity(activity), icon: const Icon(Icons.grid_on_rounded), label: Text(l10n.evaluateActivity)),
        ]))),
    ])));
  }
}

class _ProjectDialog extends StatefulWidget {
  const _ProjectDialog({required this.group});
  final TeachingGroup group;
  @override State<_ProjectDialog> createState() => _ProjectDialogState();
}
class _ProjectDialogState extends State<_ProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  ProjectMethodology _methodology = ProjectMethodology.communityProjects;
  final Set<ArticulatingAxis> _axes = {};
  final Set<PrimaryGrade> _grades = {};
  bool _gradeError = false;
  @override void dispose() { _title.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = widget.group.grades.toList()..sort((a, b) => a.number.compareTo(b.number));
    return AlertDialog(title: Text(l10n.createProject), content: SizedBox(width: 680, child: Form(key: _formKey, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(controller: _title, autofocus: true, decoration: InputDecoration(labelText: l10n.projectTitle), validator: (v) => v == null || v.trim().isEmpty ? l10n.requiredField : null),
      const SizedBox(height: 14),
      DropdownButtonFormField<ProjectMethodology>(initialValue: _methodology, decoration: InputDecoration(labelText: l10n.methodology), items: [for (final v in ProjectMethodology.values) DropdownMenuItem(value: v, child: Text(_methodologyLabel(v, l10n)))], onChanged: (v) { if (v != null) setState(() => _methodology = v); }),
      const SizedBox(height: 18), Text(l10n.articulatingAxes, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [for (final axis in ArticulatingAxis.values) FilterChip(label: Text(_axisLabel(axis, l10n)), selected: _axes.contains(axis), onSelected: (s) => setState(() => s ? _axes.add(axis) : _axes.remove(axis)))]),
      const SizedBox(height: 18), Text(l10n.grades, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
      Wrap(spacing: 8, children: [for (final grade in available) FilterChip(label: Text(_gradeLabel(grade, l10n)), selected: _grades.contains(grade), onSelected: (s) => setState(() { s ? _grades.add(grade) : _grades.remove(grade); _gradeError = false; }))]),
      if (_gradeError) Text(l10n.selectAtLeastOneGrade, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ])))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)), FilledButton(onPressed: _submit, child: Text(l10n.create))]);
  }
  void _submit() { setState(() => _gradeError = _grades.isEmpty); if (!_formKey.currentState!.validate() || _grades.isEmpty) return; Navigator.pop(context, _ProjectDraft(title: _title.text.trim(), methodology: _methodology, axes: Set.of(_axes), grades: Set.of(_grades))); }
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({required this.project}); final Project project;
  @override State<_ActivityDialog> createState() => _ActivityDialogState();
}
class _ActivityDialogState extends State<_ActivityDialog> {
  final _formKey = GlobalKey<FormState>(); final _title = TextEditingController();
  FormativeField _field = FormativeField.languages; final Set<PrimaryGrade> _grades = {}; DateTime _date = DateTime.now(); bool _gradeError = false;
  @override void dispose() { _title.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context); final grades = widget.project.targetGrades.toList()..sort((a,b)=>a.number.compareTo(b.number)); final fields = FormativeField.values.where((f)=>f != FormativeField.unspecified);
    return AlertDialog(title: Text(l10n.addActivity), content: SizedBox(width: 620, child: Form(key: _formKey, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(controller: _title, autofocus: true, decoration: InputDecoration(labelText: l10n.activityTitle), validator: (v)=>v==null||v.trim().isEmpty?l10n.requiredField:null), const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_rounded), label: Text('${_label(context, 'Fecha de realización', 'Activity date')}: ${_dateLabel(context, _date)}')), const SizedBox(height: 14),
      DropdownButtonFormField<FormativeField>(initialValue: _field, decoration: InputDecoration(labelText: l10n.activityFormativeField), items: [for(final field in fields) DropdownMenuItem(value: field, child: Text(_fieldLabel(field,l10n)))], onChanged: (v){if(v!=null)setState(()=>_field=v);}),
      const SizedBox(height: 18), Text(l10n.activityGradeScope, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height:8),
      Wrap(spacing:8, children:[for(final grade in grades) FilterChip(label:Text(_gradeLabel(grade,l10n)),selected:_grades.contains(grade),onSelected:(s)=>setState((){s?_grades.add(grade):_grades.remove(grade);_gradeError=false;}))]),
      if(_gradeError) Text(l10n.selectAtLeastOneGrade,style:TextStyle(color:Theme.of(context).colorScheme.error)), const SizedBox(height:12),
      Text(_label(context,'El campo formativo pertenece a la actividad, no al proyecto.','The formative field belongs to the activity, not the project.'),style:Theme.of(context).textTheme.bodySmall),
    ])))), actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(l10n.cancel)),FilledButton(onPressed:_submit,child:Text(l10n.create))]);
  }
  Future<void> _pickDate() async { final picked=await showDatePicker(context:context,initialDate:_date,firstDate:DateTime(2020),lastDate:DateTime(2040)); if(picked!=null)setState(()=>_date=picked); }
  void _submit(){setState(()=>_gradeError=_grades.isEmpty);if(!_formKey.currentState!.validate()||_grades.isEmpty)return;Navigator.pop(context,_ActivityDraft(title:_title.text.trim(),field:_field,grades:Set.of(_grades),date:_date));}
}

final class _ProjectDraft { const _ProjectDraft({required this.title,required this.methodology,required this.axes,required this.grades}); final String title; final ProjectMethodology methodology; final Set<ArticulatingAxis> axes; final Set<PrimaryGrade> grades; }
final class _ActivityDraft { const _ActivityDraft({required this.title,required this.field,required this.grades,required this.date}); final String title; final FormativeField field; final Set<PrimaryGrade> grades; final DateTime date; }

String _dateLabel(BuildContext context,DateTime? date)=>date==null?_label(context,'Fecha no registrada','Date not recorded'):MaterialLocalizations.of(context).formatMediumDate(date);
String _label(BuildContext context,String es,String en)=>Localizations.localeOf(context).languageCode=='en'?en:es;
String _methodologyLabel(ProjectMethodology v,AppLocalizations l)=>switch(v){ProjectMethodology.unspecified=>l.methodologyUnspecified,ProjectMethodology.communityProjects=>l.methodologyCommunityProjects,ProjectMethodology.inquirySteam=>l.methodologyInquirySteam,ProjectMethodology.problemBased=>l.methodologyProblemBased,ProjectMethodology.serviceLearning=>l.methodologyServiceLearning};
String _fieldLabel(FormativeField v,AppLocalizations l)=>switch(v){FormativeField.unspecified=>l.formativeFieldUnspecified,FormativeField.languages=>l.formativeFieldLanguages,FormativeField.knowledgeScientificThought=>l.formativeFieldScientificThought,FormativeField.ethicsNatureAndSocieties=>l.formativeFieldEthicsNature,FormativeField.humanAndCommunity=>l.formativeFieldHumanCommunity};
String _axisLabel(ArticulatingAxis v,AppLocalizations l)=>switch(v){ArticulatingAxis.inclusion=>l.axisInclusion,ArticulatingAxis.criticalThinking=>l.axisCriticalThinking,ArticulatingAxis.criticalInterculturality=>l.axisCriticalInterculturality,ArticulatingAxis.genderEquality=>l.axisGenderEquality,ArticulatingAxis.healthyLife=>l.axisHealthyLife,ArticulatingAxis.culturesReadingWriting=>l.axisCulturesReadingWriting,ArticulatingAxis.artsAestheticExperiences=>l.axisArtsAesthetic};
String _gradeLabel(PrimaryGrade g,AppLocalizations l)=>switch(g){PrimaryGrade.first=>l.grade1,PrimaryGrade.second=>l.grade2,PrimaryGrade.third=>l.grade3,PrimaryGrade.fourth=>l.grade4,PrimaryGrade.fifth=>l.grade5,PrimaryGrade.sixth=>l.grade6};
