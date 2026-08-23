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
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_controller.dart';
import 'package:aularaiz/features/student_record/presentation/student_records_controller.dart';
import 'package:aularaiz/features/student_record/presentation/student_records_screen.dart';
import 'package:aularaiz/features/student_roster/presentation/student_roster_controller.dart';
import 'package:aularaiz/features/student_roster/presentation/student_roster_screen.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SchoolWorkspaceScreen extends StatefulWidget {
  const SchoolWorkspaceScreen({super.key});

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
        context.read<SchoolWorkspaceController>().load();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: controller.isSaving ? null : _showCreateGroupDialog,
        icon: const Icon(Icons.add),
        label: Text(l10n.createGroup),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.groupsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.groupSaveError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: controller.groups.isEmpty
                    ? _EmptyGroups(message: l10n.groupsEmpty)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1100
                              ? 3
                              : constraints.maxWidth >= 680
                              ? 2
                              : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 16) /
                              columns;

                          return SingleChildScrollView(
                            child: Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                for (final group in controller.groups)
                                  SizedBox(
                                    width: width,
                                    child: _GroupCard(
                                      group: group,
                                      onStudents: () => _openStudents(group),
                                      onAttendance: () =>
                                          _openAttendance(group),
                                      onProjects: () => _openProjects(group),
                                      onEvaluation: () =>
                                          _openEvaluation(group),
                                      onRecords: () =>
                                          _openStudentRecords(group),
                                    ),
                                  ),
                              ],
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

  Future<void> _showCreateGroupDialog() async {
    final draft = await showDialog<_GroupDraft>(
      context: context,
      builder: (context) => const _CreateGroupDialog(),
    );
    if (draft == null || !mounted) return;

    await context.read<SchoolWorkspaceController>().createGroup(
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
        builder: (context) => ChangeNotifierProvider(
          create: (_) => ProjectsController(
            projectRepository: projectRepository,
            activityRepository: activityRepository,
            createProject: createProject,
            createActivity: createActivity,
          ),
          child: ProjectsScreen(group: group),
        ),
      ),
    );
  }

  Future<void> _openEvaluation(TeachingGroup group) async {
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
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
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
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
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
  });

  final TeachingGroup group;
  final VoidCallback onStudents;
  final VoidCallback onAttendance;
  final VoidCallback onProjects;
  final VoidCallback onEvaluation;
  final VoidCallback onRecords;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final grades = group.grades.toList()
      ..sort((left, right) => left.number.compareTo(right.number));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: onAttendance,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: Text(l10n.openAttendance),
                ),
                FilledButton.tonalIcon(
                  onPressed: onProjects,
                  icon: const Icon(Icons.auto_awesome_motion_outlined),
                  label: Text(l10n.openProjects),
                ),
                FilledButton.tonalIcon(
                  onPressed: onEvaluation,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(l10n.openEvaluation),
                ),
                FilledButton.tonalIcon(
                  onPressed: onRecords,
                  icon: const Icon(Icons.folder_shared_outlined),
                  label: Text(l10n.openStudentRecords),
                ),
                OutlinedButton.icon(
                  onPressed: onStudents,
                  icon: const Icon(Icons.groups_rounded),
                  label: Text(l10n.openStudents),
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
      title: Text(l10n.createGroup),
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
        name: _nameController.text,
        shift: _shiftController.text,
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
