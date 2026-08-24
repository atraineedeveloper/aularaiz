import 'dart:async';
import 'dart:io';

import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/features/school_selection/presentation/school_selection_screen.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_controller.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_screen.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_controller.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_screen.dart';
import 'package:aularaiz/infrastructure/update/github_update_service.dart';
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

    return FutureBuilder<List<InitialSchoolSetup>>(
      future: _setupsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.setupSaveError),
                ),
              ),
            ),
          );
        }

        final setups = snapshot.data ?? const <InitialSchoolSetup>[];
        if (setups.isEmpty || _creatingSchool) {
          return ChangeNotifierProvider(
            create: (context) =>
                SchoolSetupController(context.read<CreateInitialSchoolSetup>()),
            child: SchoolSetupScreen(onCompleted: _schoolSaved),
          );
        }

        final selectedSchoolId = _selectedSchoolId;
        if (selectedSchoolId == null ||
            !setups.any((setup) => setup.school.id == selectedSchoolId)) {
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

        return ChangeNotifierProvider(
          create: (context) => SchoolWorkspaceController(
            setupRepository: context.read<SchoolSetupRepository>(),
            groupRepository: context.read<TeachingGroupRepository>(),
            createTeachingGroup: context.read<CreateTeachingGroup>(),
          ),
          child: SchoolWorkspaceScreen(
            schoolId: selectedSchoolId,
            onChooseSchool: () {
              setState(() => _selectedSchoolId = null);
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteSchool(String schoolId) async {
    try {
      await context.read<SchoolSetupRepository>().deleteSchool(schoolId);
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).setupSaveError)),
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
}
