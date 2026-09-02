import 'package:aularaiz/app/layout/app_state_panel.dart';
import 'package:aularaiz/app/layout/school_workspace_shell.dart';
import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/application/project/create_activity.dart';
import 'package:aularaiz/application/project/create_project.dart';
import 'package:aularaiz/application/reports/report_projection_builder.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/application/student_record/add_student_record_entry.dart';
import 'package:aularaiz/application/student_record/update_student_record.dart';
import 'package:aularaiz/core/catalogs/mexico_geography_catalog.dart';
import 'package:aularaiz/core/catalogs/school_shift_catalog.dart';
import 'package:aularaiz/core/catalogs/school_year_catalog.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
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
import 'package:aularaiz/features/student_record/presentation/student_record_controller.dart';
import 'package:aularaiz/features/student_record/presentation/student_record_screen.dart';
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
  int _selectedDestination = 0;
  String? _activeGroupId;
  Future<bool> Function()? _activeLeaveGuard;
  StudentRecordRosterEntry? _selectedStudentRecord;

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
      return Scaffold(
        body: SafeArea(
          child: AppStatePanel(
            icon: Icons.error_outline_rounded,
            title: _label(
              context,
              'No se pudo abrir el espacio de trabajo',
              'Could not open the workspace',
            ),
            message: l10n.setupSaveError,
          ),
        ),
      );
    }

    final groups = controller.groups;
    final group = groups.isEmpty
        ? null
        : (groups
                  .where((candidate) => candidate.id == _activeGroupId)
                  .firstOrNull ??
              groups.first);
    return SchoolWorkspaceShell(
      schoolName: setup.school.name,
      schoolYearLabel: setup.schoolYear.label,
      groupName: group?.name ?? _label(context, 'Sin grupo', 'No class'),
      selectedIndex: _selectedDestination,
      groupChoices: [
        for (final candidate in groups)
          SchoolWorkspaceGroupChoice(
            id: candidate.id,
            name: candidate.name,
            subtitle: _contractSubtitle(context, candidate),
          ),
      ],
      activeGroupId: group?.id,
      onChooseGroup: groups.isEmpty
          ? null
          : (groupId) {
              setState(() => _activeGroupId = groupId);
            },
      onChooseSchool: widget.onChooseSchool,
      onEditSchool: controller.isSaving ? null : _showEditSchoolDialog,
      onOpenSettings: () => context.push('/settings'),
      destinations: group == null
          ? const <SchoolWorkspaceDestination>[]
          : <SchoolWorkspaceDestination>[
              SchoolWorkspaceDestination(
                label: _label(context, 'Inicio', 'Home'),
                icon: Icons.home_outlined,
                onSelect: () => _selectDestination(0),
              ),
              SchoolWorkspaceDestination(
                label: l10n.openStudents,
                icon: Icons.groups_outlined,
                onSelect: () => _selectDestination(1),
              ),
              SchoolWorkspaceDestination(
                label: _label(context, 'Asistencia', 'Attendance'),
                icon: Icons.fact_check_outlined,
                onSelect: () => _selectDestination(2),
              ),
              SchoolWorkspaceDestination(
                label: l10n.openProjects,
                icon: Icons.auto_awesome_motion_outlined,
                onSelect: () => _selectDestination(3),
              ),
              SchoolWorkspaceDestination(
                label: _label(context, 'Evaluación', 'Evaluation'),
                icon: Icons.assignment_turned_in_outlined,
                onSelect: () => _selectDestination(4),
              ),
              SchoolWorkspaceDestination(
                label: l10n.openStudentRecords,
                icon: Icons.folder_shared_outlined,
                onSelect: _openRecordsList,
              ),
              SchoolWorkspaceDestination(
                label: l10n.openReports,
                icon: Icons.summarize_outlined,
                onSelect: () => _selectDestination(6),
              ),
            ],
      child: group != null && _selectedStudentRecord != null
          ? ChangeNotifierProvider(
              create: (context) => StudentRecordController(
                studentRecordRepository: context
                    .read<StudentRecordRepository>(),
                attendanceRepository: context.read<AttendanceRepository>(),
                evaluationRepository: context.read<EvaluationRepository>(),
                activityRepository: context.read<ActivityRepository>(),
                updateStudentRecord: context.read<UpdateStudentRecord>(),
                addStudentRecordEntry: context.read<AddStudentRecordEntry>(),
              ),
              child: StudentRecordScreen(
                group: group,
                student: _selectedStudentRecord!.student,
                embedded: true,
                onBackToRecords: _openRecordsList,
              ),
            )
          : group != null && _selectedDestination == 1
          ? ChangeNotifierProvider(
              create: (context) => StudentRosterController(
                studentRepository: context.read<StudentRepository>(),
                enrollmentRepository: context.read<EnrollmentRepository>(),
                createStudentInGroup: context.read<CreateStudentInGroup>(),
                reactivateStudentInGroup: context
                    .read<ReactivateStudentInGroup>(),
              ),
              child: StudentRosterScreen(group: group, embedded: true),
            )
          : group != null && _selectedDestination == 2
          ? ChangeNotifierProvider(
              create: (context) => AttendanceController(
                attendanceRepository: context.read<AttendanceRepository>(),
                enrollmentRepository: context.read<EnrollmentRepository>(),
                studentRepository: context.read<StudentRepository>(),
                buildDailyAttendance: context.read<BuildDailyAttendance>(),
              ),
              child: AttendanceScreen(
                group: group,
                embedded: true,
                onLeaveGuardChanged: (guard) => _activeLeaveGuard = guard,
              ),
            )
          : group != null && _selectedDestination == 3
          ? ChangeNotifierProvider(
              create: (context) => ProjectsController(
                projectRepository: context.read<ProjectRepository>(),
                activityRepository: context.read<ActivityRepository>(),
                createProject: context.read<CreateProject>(),
                createActivity: context.read<CreateActivity>(),
              ),
              child: ProjectsScreen(
                group: group,
                embedded: true,
                onEvaluateActivity: (activity) => _openExternalDestination(
                  () => _openEvaluation(group, initialActivityId: activity.id),
                ),
              ),
            )
          : group != null && _selectedDestination == 4
          ? ChangeNotifierProvider(
              create: (context) => EvaluationController(
                projectRepository: context.read<ProjectRepository>(),
                activityRepository: context.read<ActivityRepository>(),
                studentRepository: context.read<StudentRepository>(),
                enrollmentRepository: context.read<EnrollmentRepository>(),
                evaluationRepository: context.read<EvaluationRepository>(),
                saveActivityEvaluation: context.read<SaveActivityEvaluation>(),
              ),
              child: EvaluationScreen(group: group, embedded: true),
            )
          : group != null && _selectedDestination == 5
          ? ChangeNotifierProvider(
              create: (context) => StudentRecordsController(
                enrollmentRepository: context.read<EnrollmentRepository>(),
                studentRepository: context.read<StudentRepository>(),
              ),
              child: StudentRecordsScreen(
                group: group,
                embedded: true,
                onOpenRecord: (entry) {
                  setState(() => _selectedStudentRecord = entry);
                },
              ),
            )
          : group != null && _selectedDestination == 6
          ? ChangeNotifierProvider(
              create: (context) => ReportsController(
                projectionBuilder: context.read<ReportProjectionBuilder>(),
                publicationService: context.read<ReportPublicationService>(),
              ),
              child: ReportsScreen(group: group, embedded: true),
            )
          : Center(
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
                          'Cada grupo es una asignación con sus propias fechas de contratación. Puedes registrar otro grupo en el mismo ciclo si tu contratación cambia, o iniciar el siguiente ciclo escolar cuando te recontraten.',
                          'Each class is an assignment with its own contract dates. You can register another class in the same school year if your contract changes, or start the next school year when you are rehired.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: controller.isSaving
                                ? null
                                : _showCreateGroupDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              _label(context, 'Agregar grupo', 'Add class'),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: controller.isSaving
                                ? null
                                : _showStartSchoolYearDialog,
                            icon: const Icon(Icons.event_repeat_rounded),
                            label: Text(
                              _label(
                                context,
                                'Iniciar nuevo ciclo',
                                'Start new school year',
                              ),
                            ),
                          ),
                        ],
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
                                    onStudents: () =>
                                        _openGroupDestination(group, 1),
                                    onAttendance: () =>
                                        _openGroupDestination(group, 2),
                                    onProjects: () =>
                                        _openGroupDestination(group, 3),
                                    onEvaluation: () =>
                                        _openGroupDestination(group, 4),
                                    onRecords: () =>
                                        _openGroupDestination(group, 5),
                                    onReports: () =>
                                        _openGroupDestination(group, 6),
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

  Future<void> _selectDestination(int index) async {
    if (_selectedDestination == index) return;
    if (!await _canLeaveActiveDestination()) return;
    setState(() {
      _selectedDestination = index;
      _selectedStudentRecord = null;
    });
  }

  Future<void> _openGroupDestination(TeachingGroup group, int index) async {
    if (_selectedDestination == index && _activeGroupId == group.id) return;
    if (!await _canLeaveActiveDestination()) return;
    setState(() {
      _activeGroupId = group.id;
      _selectedDestination = index;
      _selectedStudentRecord = null;
    });
  }

  String? _contractSubtitle(BuildContext context, TeachingGroup group) {
    final contract = group.contract;
    if (contract == null) return null;
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(contract.startsOn)} — '
        '${localizations.formatMediumDate(contract.endsOn)}';
  }

  void _openRecordsList() {
    setState(() {
      _selectedStudentRecord = null;
      _selectedDestination = 5;
    });
  }

  Future<void> _openExternalDestination(Future<void> Function() open) async {
    if (!await _canLeaveActiveDestination()) return;
    if (mounted) {
      setState(() {
        _selectedDestination = 0;
        _selectedStudentRecord = null;
      });
    }
    await open();
  }

  Future<bool> _canLeaveActiveDestination() async {
    final guard = _activeLeaveGuard;
    return guard == null ? true : guard();
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
        schoolZone: setup.school.schoolZone,
        schoolSector: setup.school.schoolSector,
      ),
    );
    if (draft == null || !mounted) return;
    final saved = await controller.updateSchool(
      name: draft.name,
      cct: draft.cct,
      state: draft.state,
      municipality: draft.municipality,
      locality: draft.locality,
      schoolZone: draft.schoolZone,
      schoolSector: draft.schoolSector,
    );
    if (mounted && saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _label(context, 'Escuela actualizada.', 'School updated.'),
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_schoolMutationMessage(context, controller.error)),
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
      contract: draft.contract,
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
      contract: draft.contract,
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

  Future<void> _showStartSchoolYearDialog() async {
    final controller = context.read<SchoolWorkspaceController>();
    final setup = controller.setup;
    if (setup == null || controller.isSaving) return;

    final draft = await showDialog<_SchoolYearDraft>(
      context: context,
      builder: (context) => _StartSchoolYearDialog(
        currentLabel: setup.schoolYear.label,
        currentStartsOn: setup.schoolYear.startsOn,
      ),
    );
    if (draft == null || !mounted) return;

    final started = await controller.startSchoolYear(
      schoolYearLabel: draft.label,
      startsOn: draft.startsOn,
      endsOn: draft.endsOn,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          started
              ? _label(
                  context,
                  'Ciclo ${draft.label} iniciado. Configura tu grupo.',
                  'School year ${draft.label} started. Set up your class.',
                )
              : _label(
                  context,
                  'No se pudo iniciar el ciclo. Revisa los datos e inténtalo de nuevo.',
                  'The school year could not be started. Check the data and try again.',
                ),
        ),
      ),
    );
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
  late String _shift;
  late final Set<PrimaryGrade> _grades;
  bool _showGradesError = false;
  DateTime? _contractStartsOn;
  DateTime? _contractEndsOn;
  bool _showContractError = false;

  @override
  void initState() {
    super.initState();
    final group = widget.initialGroup;
    _nameController = TextEditingController(text: group?.name ?? '');
    _shift = SchoolShiftCatalog.normalizeForSelection(group?.shift);
    _grades = Set<PrimaryGrade>.of(group?.grades ?? const <PrimaryGrade>{});
    _contractStartsOn = group?.contract?.startsOn;
    _contractEndsOn = group?.contract?.endsOn;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
                DropdownButtonFormField<String>(
                  initialValue: _shift,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.shift),
                  items: [
                    DropdownMenuItem(
                      value: SchoolShiftCatalog.unspecified,
                      child: Text(
                        _label(context, 'Sin especificar', 'Unspecified'),
                      ),
                    ),
                    for (final shift in SchoolShiftCatalog.officialValues)
                      DropdownMenuItem(
                        value: shift,
                        child: Text(_shiftLabel(context, shift)),
                      ),
                    if (_shift.isNotEmpty &&
                        !SchoolShiftCatalog.isOfficial(_shift))
                      DropdownMenuItem(
                        value: _shift,
                        child: Text(
                          _label(
                            context,
                            'Heredado: $_shift',
                            'Legacy: $_shift',
                          ),
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _shift = value);
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.contractDates,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickContractDate(start: true),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        '${l10n.contractStartDate}: '
                        '${_contractDateLabel(context, _contractStartsOn)}',
                      ),
                    ),
                    if (_contractStartsOn != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _contractStartsOn = null;
                          _showContractError = false;
                        }),
                        child: Text(
                          _label(context, 'Quitar inicio', 'Clear start'),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => _pickContractDate(start: false),
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        '${l10n.contractEndDate}: '
                        '${_contractDateLabel(context, _contractEndsOn)}',
                      ),
                    ),
                    if (_contractEndsOn != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _contractEndsOn = null;
                          _showContractError = false;
                        }),
                        child: Text(_label(context, 'Quitar fin', 'Clear end')),
                      ),
                  ],
                ),
                if (_showContractError) ...[
                  const SizedBox(height: 8),
                  Text(
                    _contractErrorMessage(context),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
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
    setState(() {
      _showGradesError = !hasGrades;
      _showContractError = _contractIsIncomplete || _contractIsReversed;
    });
    if (!_formKey.currentState!.validate() ||
        !hasGrades ||
        _showContractError) {
      return;
    }

    final contractStart = _contractStartsOn;
    final contractEnd = _contractEndsOn;
    Navigator.of(context).pop(
      _GroupDraft(
        name: _nameController.text.trim(),
        shift: SchoolShiftCatalog.persistenceValue(_shift),
        grades: Set<PrimaryGrade>.of(_grades),
        contract: contractStart != null && contractEnd != null
            ? TeachingContract(startsOn: contractStart, endsOn: contractEnd)
            : null,
      ),
    );
  }

  Future<void> _pickContractDate({required bool start}) async {
    final current = start ? _contractStartsOn : _contractEndsOn;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _contractStartsOn ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;

    setState(() {
      if (start) {
        _contractStartsOn = picked;
      } else {
        _contractEndsOn = picked;
      }
      _showContractError = false;
    });
  }

  String _contractDateLabel(BuildContext context, DateTime? date) {
    if (date == null) {
      return AppLocalizations.of(context).selectDate;
    }
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  bool get _contractIsIncomplete =>
      (_contractStartsOn == null) != (_contractEndsOn == null);

  bool get _contractIsReversed =>
      _contractStartsOn != null &&
      _contractEndsOn != null &&
      _contractEndsOn!.isBefore(_contractStartsOn!);

  String _contractErrorMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _contractIsReversed
        ? l10n.invalidDateRange
        : l10n.contractIncomplete;
  }
}

final class _SchoolYearDraft {
  const _SchoolYearDraft({
    required this.label,
    required this.startsOn,
    required this.endsOn,
  });

  final String label;
  final DateTime startsOn;
  final DateTime endsOn;
}

class _StartSchoolYearDialog extends StatefulWidget {
  const _StartSchoolYearDialog({
    required this.currentLabel,
    required this.currentStartsOn,
  });

  final String currentLabel;
  final DateTime currentStartsOn;

  @override
  State<_StartSchoolYearDialog> createState() => _StartSchoolYearDialogState();
}

class _StartSchoolYearDialogState extends State<_StartSchoolYearDialog> {
  late final SchoolYearPreset _preset;

  @override
  void initState() {
    super.initState();
    final options = _upcomingOptions();
    _preset = options.isEmpty
        ? SchoolYearCatalog.basicEducationOptions.last
        : options.first;
  }

  List<SchoolYearPreset> _upcomingOptions() {
    return SchoolYearCatalog.basicEducationOptions
        .where((option) => option.startsOn.isAfter(widget.currentStartsOn))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = _upcomingOptions();

    return AlertDialog(
      title: Text(
        _label(context, 'Iniciar nuevo ciclo', 'Start new school year'),
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label(
                context,
                'El ciclo “${widget.currentLabel}” quedará guardado con sus grupos y registros. El ciclo que elijas será el activo para trabajar.',
                'The “${widget.currentLabel}” school year will remain saved with its classes and records. The school year you choose becomes the active one.',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _preset.label,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.schoolYear),
              items: [
                for (final option
                    in options.isEmpty
                        ? SchoolYearCatalog.basicEducationOptions
                        : options)
                  DropdownMenuItem(
                    value: option.label,
                    child: Text(option.label),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _preset = SchoolYearCatalog.basicEducationOptions.firstWhere(
                    (option) => option.label == value,
                  );
                });
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
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              _SchoolYearDraft(
                label: _preset.label,
                startsOn: _preset.startsOn,
                endsOn: _preset.endsOn,
              ),
            );
          },
          icon: const Icon(Icons.event_repeat_rounded),
          label: Text(_label(context, 'Iniciar ciclo', 'Start school year')),
        ),
      ],
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
    this.schoolZone,
    this.schoolSector,
  });

  final String name;
  final String? cct;
  final String? state;
  final String? municipality;
  final String? locality;
  final String? schoolZone;
  final String? schoolSector;

  @override
  State<_EditSchoolDialog> createState() => _EditSchoolDialogState();
}

class _EditSchoolDialogState extends State<_EditSchoolDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _cctController;
  late final TextEditingController _localityController;
  late final TextEditingController _schoolZoneController;
  late final TextEditingController _schoolSectorController;
  String? _state;
  String? _municipality;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _cctController = TextEditingController(text: widget.cct ?? '');
    _localityController = TextEditingController(text: widget.locality ?? '');
    _schoolZoneController = TextEditingController(
      text: widget.schoolZone ?? '',
    );
    _schoolSectorController = TextEditingController(
      text: widget.schoolSector ?? '',
    );
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
    _schoolZoneController.dispose();
    _schoolSectorController.dispose();
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
                const SizedBox(height: 14),
                TextFormField(
                  controller: _schoolZoneController,
                  decoration: InputDecoration(
                    labelText: _label(context, 'Zona escolar', 'School zone'),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _schoolSectorController,
                  decoration: InputDecoration(
                    labelText: _label(
                      context,
                      'Sector escolar',
                      'School sector',
                    ),
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
        schoolZone: _schoolZoneController.text.trim(),
        schoolSector: _schoolSectorController.text.trim(),
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
    this.contract,
  });

  final String name;
  final String? shift;
  final Set<PrimaryGrade> grades;
  final TeachingContract? contract;
}

final class _SchoolDraft {
  const _SchoolDraft({
    required this.name,
    required this.cct,
    required this.state,
    required this.municipality,
    required this.locality,
    required this.schoolZone,
    required this.schoolSector,
  });

  final String name;
  final String cct;
  final String? state;
  final String? municipality;
  final String locality;
  final String schoolZone;
  final String schoolSector;
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

String _shiftLabel(BuildContext context, String shift) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  if (!english) return shift;
  return switch (shift) {
    SchoolShiftCatalog.morning => 'Morning',
    SchoolShiftCatalog.afternoon => 'Afternoon',
    SchoolShiftCatalog.night => 'Night',
    SchoolShiftCatalog.discontinuous => 'Discontinuous',
    SchoolShiftCatalog.continuous => 'Continuous',
    _ => shift,
  };
}

String _label(BuildContext context, String spanish, String english) {
  return Localizations.localeOf(context).languageCode == 'en'
      ? english
      : spanish;
}

String _schoolMutationMessage(BuildContext context, Object? error) {
  final detail = error.toString().toLowerCase();
  final english = Localizations.localeOf(context).languageCode == 'en';
  if (detail.contains('unique') || detail.contains('schools.cct')) {
    return english
        ? 'The CCT is already assigned to another school.'
        : 'El CCT ya está asignado a otra escuela.';
  }
  if (detail.contains('locked') || detail.contains('readonly')) {
    return english
        ? 'The local data file is in use or cannot be written.'
        : 'El archivo de datos local está en uso o no se puede modificar.';
  }
  return AppLocalizations.of(context).setupSaveError;
}
