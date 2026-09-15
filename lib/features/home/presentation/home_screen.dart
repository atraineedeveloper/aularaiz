import 'dart:async';
import 'dart:io';

import 'package:aularaiz/app/layout/app_state_panel.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/application/school_setup/start_school_year.dart';
import 'package:aularaiz/application/teacher/save_teacher_profile.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/features/school_selection/presentation/school_selection_screen.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_controller.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_screen.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_controller.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_screen.dart';
import 'package:aularaiz/infrastructure/sync/sync_refresh_listener.dart';
import 'package:aularaiz/infrastructure/update/github_update_service.dart';
import 'package:aularaiz/infrastructure/window/window_title_service.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<InitialSchoolSetup>>? _setupsFuture;
  String? _selectedSchoolId;
  bool _creatingSchool = false;
  bool _startupUpdateCheckStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupsFuture ??= context.read<SchoolSetupRepository>().listSetups();
    _startBackgroundUpdateCheck();
  }

  void _startBackgroundUpdateCheck() {
    if (_startupUpdateCheckStarted || !Platform.isWindows) return;
    _startupUpdateCheckStarted = true;
    unawaited(_checkForUpdateAfterStartup());
  }

  Future<void> _checkForUpdateAfterStartup() async {
    try {
      final update = await GithubUpdateService().checkForUpdate();
      if (!mounted || update == null) return;

      final english = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            english
                ? 'AulaRaíz ${update.version} is available.'
                : 'AulaRaíz ${update.version} está disponible.',
          ),
          action: SnackBarAction(
            label: english ? 'Update' : 'Actualizar',
            onPressed: () => context.push('/settings'),
          ),
          duration: const Duration(seconds: 12),
        ),
      );
    } catch (_) {
      // Update discovery must never interrupt classroom startup or local work.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SyncRefreshListener(
      onRefresh: _refreshAfterSync,
      child: FutureBuilder<List<InitialSchoolSetup>>(
        future: _setupsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            _setWindowTitle('AulaRaíz');
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            _setWindowTitle(_windowTitle('Mis escuelas'));
            return Scaffold(
              body: SafeArea(
                child: AppStatePanel(
                  icon: Icons.error_outline_rounded,
                  title: Localizations.localeOf(context).languageCode == 'en'
                      ? 'Could not load your schools'
                      : 'No se pudieron cargar tus escuelas',
                  message: l10n.setupSaveError,
                ),
              ),
            );
          }

          final setups = snapshot.data ?? const <InitialSchoolSetup>[];
          if (_creatingSchool) {
            _setWindowTitle(_windowTitle('Configuración inicial'));
            return ChangeNotifierProvider(
              create: (context) => SchoolSetupController(
                context.read<CreateInitialWorkspace>(),
                saveTeacherProfile: context.read<SaveTeacherProfile>(),
              ),
              child: SchoolSetupScreen(onCompleted: _schoolSaved),
            );
          }

          final selectedSchoolId = _selectedSchoolId;
          if (setups.isEmpty ||
              selectedSchoolId == null ||
              !setups.any((setup) => setup.school.id == selectedSchoolId)) {
            _setWindowTitle(_windowTitle('Mis escuelas'));
            return SchoolSelectionScreen(
              setups: setups,
              onSelect: (schoolId) {
                setState(() => _selectedSchoolId = schoolId);
              },
              onDeleteSchool: _deleteSchool,
              onCreateSchool: () {
                setState(() => _creatingSchool = true);
              },
              onOpenSettings: () => context.push('/settings'),
            );
          }

          final selectedSetup = setups.firstWhere(
            (setup) => setup.school.id == selectedSchoolId,
          );
          _setWindowTitle(
            _windowTitle(
              '${selectedSetup.school.name} · '
              '${selectedSetup.schoolYear.label}',
            ),
          );
          return ChangeNotifierProvider(
            create: (context) => SchoolWorkspaceController(
              setupRepository: context.read<SchoolSetupRepository>(),
              groupRepository: context.read<TeachingGroupRepository>(),
              createTeachingGroup: context.read<CreateTeachingGroup>(),
              startSchoolYear: context.read<StartSchoolYear>(),
            ),
            child: SchoolWorkspaceScreen(
              schoolId: selectedSchoolId,
              onChooseSchool: () {
                setState(() => _selectedSchoolId = null);
              },
            ),
          );
        },
      ),
    );
  }

  void _setWindowTitle(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(WindowTitleService.setTitle(title));
    });
  }

  Future<void> _deleteSchool(String schoolId) async {
    try {
      await context.read<SchoolSetupRepository>().deleteSchool(schoolId);
      SafeLog.operationSuccess('delete_school');
      if (!mounted) return;
      setState(() {
        if (_selectedSchoolId == schoolId) _selectedSchoolId = null;
        _setupsFuture = context.read<SchoolSetupRepository>().listSetups();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? 'School deleted.'
                : 'Escuela eliminada.',
          ),
        ),
      );
    } catch (error) {
      SafeLog.operationFailure('delete_school', error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_schoolDeletionMessage(context, error))),
      );
    }
  }

  void _schoolSaved() {
    setState(() {
      _creatingSchool = false;
      _selectedSchoolId = null;
      _setupsFuture = context.read<SchoolSetupRepository>().listSetups();
    });
  }

  Future<void> _refreshAfterSync() async {
    if (!mounted || _creatingSchool) return;
    setState(() {
      _setupsFuture = context.read<SchoolSetupRepository>().listSetups();
    });
  }
}

String _windowTitle(String segment) => 'AulaRaíz · $segment';

String _schoolDeletionMessage(BuildContext context, Object error) {
  final detail = error.toString().toLowerCase();
  final english = Localizations.localeOf(context).languageCode == 'en';
  if (detail.contains('locked') || detail.contains('readonly')) {
    return english
        ? 'The local data file is in use or cannot be written.'
        : 'El archivo de datos local está en uso o no se puede modificar.';
  }
  return english
      ? 'The school could not be deleted. Check the local data log for details.'
      : 'No se pudo eliminar la escuela. Revisa el registro local para ver el detalle.';
}
