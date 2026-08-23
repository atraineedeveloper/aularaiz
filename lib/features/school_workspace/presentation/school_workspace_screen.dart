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
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/attendance/presentation/attendance_controller.dart';
import 'package:aularaiz/features/attendance/presentation/attendance_screen.dart';
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
    if (!_loadStarted) {
      _loadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<SchoolWorkspaceController>().load(widget.schoolId);
      });
    }
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: _label(context, 'Cambiar escuela', 'Choose another school'),
          onPressed: widget.onChooseSchool,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(setup.school.name),
            Text(
              setup.schoolYear.label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
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
                      l10n.groupSaveError,
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
                                onStudents: () => _openStudents(group),
                                onAttendance: () => _openAttendance(group),
                                onProjects: () => _openProjects(group),
                                onEvaluation: () => _openEvaluation(group),
                                onRecords: () => _openStudentRecords(group),
                                onReports: () => _openReports(group),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateGroupDialog() async {
    final controller = context.read<SchoolWorkspaceController>();
    if (!controller.canCreateGroup) return;
    final draft = await showDialog<_GroupDraft>(
      context: context,
      builder: (context) => const _CreateGroupDialog(),
    );
    if (draft == null || !mounted) return;

    await controller.createGroup(
      name: draft.name,
      grades: draft.grades,
      shift: draft.shift,
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
    final evaluationRepository = context.read<EvaluationRepository>();
    final saveActivityEvaluation = context.read<SaveActivityEvaluation>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => EvaluationController(
            projectRepository: projectRepository,
            activityRepository: activityRepository,
            studentRepository: studentRepository,
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
    required this.onStudents,
    required this.onAttendance,
    required this.onProjects,
    required this.onEvaluation,
    required this.onRecords,
    required this.onReports,
  });

  final TeachingGroup group;
  final VoidCallback onStudents;
  final VoidCallback onAttendance;
  final VoidCallback onProjects;
  final VoidCallback onEvaluation;
  final VoidCallback onRecords;
  final VoidCallback onReports;

  @override
  Widget build(BuildContext context) {
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  group.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
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

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _shiftController = TextEditingController();
  final Set<PrimaryGrade> _grades = {};
  bool _showGradesError = false;

  @override
  void dispose() {
    _nameController.dispose();
    _shiftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(_label(context, 'Configurar mi grupo', 'Set up my class')),
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
        FilledButton(onPressed: _submit, child: Text(l10n.create)),
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
