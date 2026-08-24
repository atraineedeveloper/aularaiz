import 'package:aularaiz/app/layout/school_workspace_shell.dart';
import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/application/project/create_activity.dart';
import 'package:aularaiz/application/project/create_project.dart';
import 'package:aularaiz/application/reports/report_projection_builder.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/core/catalogs/mexico_geography_catalog.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/attendance/presentation/attendance_controller.dart';
import 'package:aularaiz/features/attendance/presentation/attendance_screen.dart';
import 'package:aularaiz/features/dashboard/presentation/group_dashboard_controller.dart';
import 'package:aularaiz/features/dashboard/presentation/group_dashboard_screen.dart';
import 'package:aularaiz/features/evaluation/presentation/evaluation_controller.dart';
import 'package:aularaiz/features/evaluation/presentation/evaluation_screen.dart';
import 'package:aularaiz/features/projects/presentation/projects_controller.dart';
import 'package:aularaiz/features/projects/presentation/projects_screen.dart';
import 'package:aularaiz/features/reports/presentation/reports_controller.dart';
import 'package:aularaiz/features/reports/presentation/reports_screen.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_controller.dart';
import 'package:aularaiz/features/student_record/presentation/student_records_controller.dart';
import 'package:aularaiz/features/student_record/presentation/student_records_screen.dart';
import 'package:aularaiz/features/student_roster/presentation/student_roster_controller.dart';
import 'package:aularaiz/features/student_roster/presentation/student_roster_screen.dart';
import 'package:aularaiz/infrastructure/reports/report_publication_service.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SchoolWorkspaceScreen extends StatefulWidget {
  const SchoolWorkspaceScreen({
    required this.schoolId,
    required this.onChooseSchool,
    super.key,
  });

  final String schoolId;
  final VoidCallback onChooseSchool;

  @override
  State<SchoolWorkspaceScreen> createState() => _SchoolWorkspaceScreenState();
}

class _SchoolWorkspaceScreenState extends State<SchoolWorkspaceScreen> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SchoolWorkspaceController>().load(widget.schoolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<SchoolWorkspaceController>();
    final setup = controller.setup;

    if (controller.isLoading && setup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (setup == null) {
      return Scaffold(body: Center(child: Text(l10n.setupSaveError)));
    }

    final group = controller.groups.isEmpty ? null : controller.groups.first;
    return SchoolWorkspaceShell(
      schoolName: setup.school.name,
      schoolYearLabel: setup.schoolYear.label,
      groupName: group?.name ?? _label(context, 'Sin grupo', 'No class'),
      onChooseSchool: widget.onChooseSchool,
      onEditSchool: controller.isSaving ? null : _showEditSchoolDialog,
      onOpenSettings: () => context.push('/settings'),
      destinations: group == null
          ? const <SchoolWorkspaceDestination>[]
          : <SchoolWorkspaceDestination>[
              SchoolWorkspaceDestination(
                label: _label(context, 'Inicio', 'Home'),
                icon: Icons.home_outlined,
                onSelect: () {},
              ),
              SchoolWorkspaceDestination(
                label: l10n.openStudents,
                icon: Icons.groups_outlined,
                onSelect: () => _openStudents(group),
              ),
              SchoolWorkspaceDestination(
                label: _label(context, 'Asistencia', 'Attendance'),
                icon: Icons.fact_check_outlined,
                onSelect: () => _openAttendance(group),
              ),
              SchoolWorkspaceDestination(
                label: l10n.openProjects,
                icon: Icons.auto_awesome_motion_outlined,
                onSelect: () => _openProjects(group),
              ),
              SchoolWorkspaceDestination(
                label: _label(context, 'Evaluación', 'Evaluation'),
                icon: Icons.assignment_turned_in_outlined,
                onSelect: () => _openEvaluation(group),
              ),
              SchoolWorkspaceDestination(
                label: l10n.openStudentRecords,
                icon: Icons.folder_shared_outlined,
                onSelect: () => _openStudentRecords(group),
              ),
              SchoolWorkspaceDestination(
                label: l10n.openReports,
                icon: Icons.summarize_outlined,
                onSelect: () => _openReports(group),
              ),
            ],
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _label(context, 'Mi grupo', 'My class'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _label(
                    context,
                    'En primaria AulaRaíz administra un solo grupo por escuela y ciclo escolar. Puede ser unigrado o multigrado.',
                    'For primary school, AulaRaíz manages one class per school and school year. It may be single-grade or multigrade.',
                  ),
                ),
                if (controller.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _label(
                      context,
                      'No se pudo guardar el cambio. Revisa los datos e inténtalo de nuevo.',
                      'The change could not be saved. Check the data and try again.',
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Expanded(
                  child: controller.groups.isEmpty
                      ? _EmptyGroup(
                          isSaving: controller.isSaving,
                          onCreate: _showCreateGroupDialog,
                        )
                      : ListView.separated(
                          itemCount: controller.groups.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 16),
                          itemBuilder: (context, index) {
                            final group = controller.groups[index];
                            return _GroupCard(
                              group: group,
                              onEdit: () => _showEditGroupDialog(group),
                              onDelete: () => _confirmDeleteGroup(group),
                              onDashboard: () => _openDashboard(group),
                              onStudents: () => _openStudents(group),
                              onAttendance: () => _openAttendance(group),
                              onProjects: () => _openProjects(group),
                              onEvaluation: () => _openEvaluation(group),
                              onRecords: () => _openStudentRecords(group),
                              onReports: () => _openReports(group),
                              modernOverview: true,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditSchoolDialog() async {
    final controller = context.read<SchoolWorkspaceController>();
    final setup = controller.setup;
    if (setup == null) return;
    final draft = await showDialog<_SchoolDraft>(
      context: context,
      builder: (context) => _EditSchoolDialog(
        name: setup.school.name,
        cct: setup.school.cct,
        state: setup.school.state,
        municipality: setup.school.municipality,
        locality: setup.school.locality,
      ),
    );
    if (draft == null || !mounted) return;
    final saved = await controller.updateSchool(
      name: draft.name,
      cct: draft.cct,
      state: draft.state,
      municipality: draft.municipality,
      locality: draft.locality,
    );
    if (mounted && saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(context, 'Escuela actualizada.', 'School updated.'),
          ),
        ),
      );
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final controller = context.read<SchoolWorkspaceController>();
    if (!controller.canCreateGroup) return;
    final draft = await showDialog<_GroupDraft>(
      context: context,
      builder: (context) => const _GroupDialog(),
    );
    if (draft == null || !mounted) return;
    await controller.createGroup(
      name: draft.name,
      grades: draft.grades,
      shift: draft.shift,
    );
  }

  Future<void> _showEditGroupDialog(TeachingGroup group) async {
    final controller = context.read<SchoolWorkspaceController>();
    final draft = await showDialog<_GroupDraft>(
      context: context,
      builder: (context) => _GroupDialog(initialGroup: group),
    );
    if (draft == null || !mounted) return;
    final saved = await controller.updateGroup(
      group: group,
      name: draft.name,
      grades: draft.grades,
      shift: draft.shift,
    );
    if (mounted && saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(context, 'Grupo actualizado.', 'Class updated.'),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteGroup(TeachingGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(_label(context, '¿Eliminar grupo?', 'Delete class?')),
        content: Text(
          _label(
            context,
            'Se eliminará permanentemente “${group.name}” con sus matrículas, asistencias, proyectos, actividades y evaluaciones. Esta acción no se puede deshacer.',
            '“${group.name}” will be permanently deleted with its enrollments, attendance, projects, activities and evaluations. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_label(context, 'Eliminar', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await context.read<SchoolWorkspaceController>().deleteGroup(
      group,
    );
    if (mounted && deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_label(context, 'Grupo eliminado.', 'Class deleted.')),
        ),
      );
    }
  }

  Future<void> _openDashboard(TeachingGroup group) async {
    final enrollmentRepository = context.read<EnrollmentRepository>();
    final studentRepository = context.read<StudentRepository>();
    final attendanceRepository = context.read<AttendanceRepository>();
    final projectRepository = context.read<ProjectRepository>();
    final activityRepository = context.read<ActivityRepository>();
    final evaluationRepository = context.read<EvaluationRepository>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => GroupDashboardController(
            enrollmentRepository: enrollmentRepository,
            studentRepository: studentRepository,
            attendanceRepository: attendanceRepository,
            projectRepository: projectRepository,
            activityRepository: activityRepository,
            evaluationRepository: evaluationRepository,
          ),
          child: GroupDashboardScreen(group: group),
        ),
      ),
    );
  }

  Future<void> _openStudents(TeachingGroup group) async {
    final studentRepository = context.read<StudentRepository>();
    final enrollmentRepository = context.read<EnrollmentRepository>();
    final createStudentInGroup = context.read<CreateStudentInGroup>();
    final reactivateStudentInGroup = context.read<ReactivateStudentInGroup>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => StudentRosterController(
            studentRepository: studentRepository,
            enrollmentRepository: enrollmentRepository,
            createStudentInGroup: createStudentInGroup,
            reactivateStudentInGroup: reactivateStudentInGroup,
          ),
          child: StudentRosterScreen(group: group),
        ),
      ),
    );
  }

  Future<void> _openAttendance(TeachingGroup group) async {
    final attendanceRepository = context.read<AttendanceRepository>();
    final enrollmentRepository = context.read<EnrollmentRepository>();
    final studentRepository = context.read<StudentRepository>();
    final buildDailyAttendance = context.read<BuildDailyAttendance>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => AttendanceController(
            attendanceRepository: attendanceRepository,
            enrollmentRepository: enrollmentRepository,
            studentRepository: studentRepository,
            buildDailyAttendance: buildDailyAttendance,
          ),
          child: AttendanceScreen(group: group),
        ),
      ),
    );
  }

  Future<void> _openProjects(TeachingGroup group) async {
    final projectRepository = context.read<ProjectRepository>();
    final activityRepository = context.read<ActivityRepository>();
    final createProject = context.read<CreateProject>();
    final createActivity = context.read<CreateActivity>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => ChangeNotifierProvider(
          create: (_) => ProjectsController(
            projectRepository: projectRepository,
            activityRepository: activityRepository,
            createProject: createProject,
            createActivity: createActivity,
          ),
          child: ProjectsScreen(
            group: group,
            onEvaluateActivity: (activity) {
              _openEvaluation(group, initialActivityId: activity.id);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openEvaluation(
    TeachingGroup group, {
    String? initialActivityId,
  }) async {
    final projectRepository = context.read<ProjectRepository>();
    final activityRepository = context.read<ActivityRepository>();
    final studentRepository = context.read<StudentRepository>();
    final enrollmentRepository = context.read<EnrollmentRepository>();
    final evaluationRepository = context.read<EvaluationRepository>();
    final saveActivityEvaluation = context.read<SaveActivityEvaluation>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => EvaluationController(
            projectRepository: projectRepository,
            activityRepository: activityRepository,
            studentRepository: studentRepository,
            enrollmentRepository: enrollmentRepository,
            evaluationRepository: evaluationRepository,
            saveActivityEvaluation: saveActivityEvaluation,
            initialActivityId: initialActivityId,
          ),
          child: EvaluationScreen(group: group),
        ),
      ),
    );
  }

  Future<void> _openStudentRecords(TeachingGroup group) async {
    final enrollmentRepository = context.read<EnrollmentRepository>();
    final studentRepository = context.read<StudentRepository>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => StudentRecordsController(
            enrollmentRepository: enrollmentRepository,
            studentRepository: studentRepository,
          ),
          child: StudentRecordsScreen(group: group),
        ),
      ),
    );
  }

  Future<void> _openReports(TeachingGroup group) async {
    final projectionBuilder = context.read<ReportProjectionBuilder>();
    final publicationService = context.read<ReportPublicationService>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => ReportsController(
            projectionBuilder: projectionBuilder,
            publicationService: publicationService,
          ),
          child: ReportsScreen(group: group),
        ),
      ),
    );
  }
}

class _EmptyGroup extends StatelessWidget {
  const _EmptyGroup({required this.isSaving, required this.onCreate});

  final bool isSaving;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                Text(
                  _label(
                    context,
                    'Configura el grupo que atiendes',
                    'Set up the class you teach',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _label(
                    context,
                    'Podrás elegir uno o varios grados si trabajas en un grupo multigrado.',
                    'You may choose one or more grades if you teach a multigrade class.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: isSaving ? null : onCreate,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    _label(context, 'Configurar mi grupo', 'Set up my class'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onEdit,
    required this.onDelete,
    required this.onDashboard,
    required this.onStudents,
    required this.onAttendance,
    required this.onProjects,
    required this.onEvaluation,
    required this.onRecords,
    required this.onReports,
    required this.modernOverview,
  });

  final TeachingGroup group;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDashboard;
  final VoidCallback onStudents;
  final VoidCallback onAttendance;
  final VoidCallback onProjects;
  final VoidCallback onEvaluation;
  final VoidCallback onRecords;
  final VoidCallback onReports;
  final bool modernOverview;

  @override
  Widget build(BuildContext context) {
    if (modernOverview) {
      return ChangeNotifierProvider(
        create: (context) => GroupDashboardController(
          enrollmentRepository: context.read<EnrollmentRepository>(),
          studentRepository: context.read<StudentRepository>(),
          attendanceRepository: context.read<AttendanceRepository>(),
          projectRepository: context.read<ProjectRepository>(),
          activityRepository: context.read<ActivityRepository>(),
          evaluationRepository: context.read<EvaluationRepository>(),
        ),
        child: GroupDashboardOverview(
          group: group,
          onEditGroup: onEdit,
          onDeleteGroup: onDelete,
          onOpenStudents: onStudents,
          onOpenAttendance: onAttendance,
          onOpenEvaluation: onEvaluation,
          onOpenDetailedDashboard: onDashboard,
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final grades = group.grades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: _label(context, 'Editar grupo', 'Edit class'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: _label(context, 'Eliminar grupo', 'Delete class'),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 4),
                Chip(
                  label: Text(
                    group.isMultigrade ? l10n.multigrade : l10n.unigrade,
                  ),
                ),
              ],
            ),
            if (group.shift != null) ...[
              const SizedBox(height: 8),
              Text('${l10n.shift}: ${group.shift}'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final grade in grades)
                  Chip(label: Text(_gradeLabel(grade, l10n))),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              _label(context, 'Acciones del día', 'Daily actions'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onAttendance,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: Text(
                    _label(context, 'Tomar asistencia', 'Take attendance'),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onEvaluation,
                  icon: const Icon(Icons.assignment_turned_in_rounded),
                  label: Text(
                    _label(
                      context,
                      'Evaluar actividades',
                      'Evaluate activities',
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              _label(context, 'Gestión del grupo', 'Class management'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onDashboard,
                  icon: const Icon(Icons.dashboard_outlined),
                  label: Text(
                    _label(context, 'Resumen del grupo', 'Class dashboard'),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onProjects,
                  icon: const Icon(Icons.auto_awesome_motion_outlined),
                  label: Text(l10n.openProjects),
                ),
                FilledButton.tonalIcon(
                  onPressed: onStudents,
                  icon: const Icon(Icons.groups_rounded),
                  label: Text(l10n.openStudents),
                ),
                FilledButton.tonalIcon(
                  onPressed: onRecords,
                  icon: const Icon(Icons.folder_shared_outlined),
                  label: Text(l10n.openStudentRecords),
                ),
                FilledButton.tonalIcon(
                  onPressed: onReports,
                  icon: const Icon(Icons.summarize_outlined),
                  label: Text(l10n.openReports),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog({this.initialGroup});

  final TeachingGroup? initialGroup;

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _shiftController;
  late final Set<PrimaryGrade> _grades;
  bool _showGradesError = false;

  @override
  void initState() {
    super.initState();
    final group = widget.initialGroup;
    _nameController = TextEditingController(text: group?.name ?? '');
    _shiftController = TextEditingController(text: group?.shift ?? '');
    _grades = Set<PrimaryGrade>.of(group?.grades ?? const <PrimaryGrade>{});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shiftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.initialGroup != null;

    return AlertDialog(
      title: Text(
        editing
            ? _label(context, 'Editar grupo', 'Edit class')
            : _label(context, 'Configurar mi grupo', 'Set up my class'),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(labelText: l10n.groupName),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _shiftController,
                  decoration: InputDecoration(labelText: l10n.shift),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.grades,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final grade in PrimaryGrade.values)
                      FilterChip(
                        label: Text(_gradeLabel(grade, l10n)),
                        selected: _grades.contains(grade),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _grades.add(grade);
                            } else {
                              _grades.remove(grade);
                            }
                            _showGradesError = false;
                          });
                        },
                      ),
                  ],
                ),
                if (_showGradesError) ...[
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
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? l10n.save : l10n.create),
        ),
      ],
    );
  }

  void _submit() {
    final hasGrades = _grades.isNotEmpty;
    setState(() => _showGradesError = !hasGrades);
    if (!_formKey.currentState!.validate() || !hasGrades) return;
    Navigator.of(context).pop(
      _GroupDraft(
        name: _nameController.text.trim(),
        shift: _shiftController.text.trim(),
        grades: Set<PrimaryGrade>.of(_grades),
      ),
    );
  }
}

class _EditSchoolDialog extends StatefulWidget {
  const _EditSchoolDialog({
    required this.name,
    this.cct,
    this.state,
    this.municipality,
    this.locality,
  });

  final String name;
  final String? cct;
  final String? state;
  final String? municipality;
  final String? locality;

  @override
  State<_EditSchoolDialog> createState() => _EditSchoolDialogState();
}

class _EditSchoolDialogState extends State<_EditSchoolDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cctController;
  late final TextEditingController _localityController;
  String? _state;
  String? _municipality;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _cctController = TextEditingController(text: widget.cct ?? '');
    _localityController = TextEditingController(text: widget.locality ?? '');
    _state =
        MexicoGeographyCatalog.states.any((item) => item.name == widget.state)
        ? widget.state
        : null;
    final municipalities = _municipalitiesFor(_state);
    _municipality = municipalities.contains(widget.municipality)
        ? widget.municipality
        : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cctController.dispose();
    _localityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final municipalities = _municipalitiesFor(_state);

    return AlertDialog(
      title: Text(_label(context, 'Editar escuela', 'Edit school')),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _label(
                      context,
                      'Nombre de la escuela',
                      'School name',
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? l10n.requiredField
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cctController,
                  decoration: const InputDecoration(labelText: 'CCT'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _state,
                  decoration: InputDecoration(
                    labelText: _label(context, 'Estado', 'State'),
                  ),
                  items: [
                    for (final state in MexicoGeographyCatalog.states)
                      DropdownMenuItem(
                        value: state.name,
                        child: Text(state.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _state = value;
                      _municipality = null;
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey(_state),
                  initialValue: _municipality,
                  decoration: InputDecoration(
                    labelText: _label(context, 'Municipio', 'Municipality'),
                  ),
                  items: [
                    for (final municipality in municipalities)
                      DropdownMenuItem(
                        value: municipality,
                        child: Text(municipality),
                      ),
                  ],
                  onChanged: municipalities.isEmpty
                      ? null
                      : (value) => setState(() => _municipality = value),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _localityController,
                  decoration: InputDecoration(
                    labelText: _label(context, 'Localidad', 'Locality'),
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _SchoolDraft(
        name: _nameController.text.trim(),
        cct: _cctController.text.trim(),
        state: _state,
        municipality: _municipality,
        locality: _localityController.text.trim(),
      ),
    );
  }

  List<String> _municipalitiesFor(String? stateName) {
    if (stateName == null) return const [];
    return MexicoGeographyCatalog.states
            .where((state) => state.name == stateName)
            .firstOrNull
            ?.municipalities ??
        const [];
  }
}

final class _GroupDraft {
  const _GroupDraft({
    required this.name,
    required this.shift,
    required this.grades,
  });

  final String name;
  final String shift;
  final Set<PrimaryGrade> grades;
}

final class _SchoolDraft {
  const _SchoolDraft({
    required this.name,
    required this.cct,
    required this.state,
    required this.municipality,
    required this.locality,
  });

  final String name;
  final String cct;
  final String? state;
  final String? municipality;
  final String locality;
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

String _label(BuildContext context, String spanish, String english) {
  return Localizations.localeOf(context).languageCode == 'en'
      ? english
      : spanish;
}
