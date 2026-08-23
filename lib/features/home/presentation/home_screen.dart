import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/features/school_selection/presentation/school_selection_screen.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_controller.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_screen.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_controller.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_screen.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupsFuture ??= context.read<SchoolSetupRepository>().listSetups();
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

  void _schoolSaved() {
    setState(() {
      _creatingSchool = false;
      _selectedSchoolId = null;
      _setupsFuture = context.read<SchoolSetupRepository>().listSetups();
    });
  }
}
