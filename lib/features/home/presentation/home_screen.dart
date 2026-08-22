import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_controller.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_screen.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_controller.dart';
import 'package:aularaiz/features/school_workspace/presentation/school_workspace_screen.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<bool>? _setupFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupFuture ??= context.read<SchoolSetupRepository>().hasInitialSetup();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<bool>(
      future: _setupFuture,
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

        if (snapshot.data != true) {
          return ChangeNotifierProvider(
            create: (context) => SchoolSetupController(
              context.read<CreateInitialSchoolSetup>(),
            ),
            child: SchoolSetupScreen(onCompleted: _refreshSetupState),
          );
        }

        return ChangeNotifierProvider(
          create: (context) => SchoolWorkspaceController(
            setupRepository: context.read<SchoolSetupRepository>(),
            groupRepository: context.read<TeachingGroupRepository>(),
            createTeachingGroup: context.read<CreateTeachingGroup>(),
          ),
          child: const SchoolWorkspaceScreen(),
        );
      },
    );
  }

  void _refreshSetupState() {
    setState(() {
      _setupFuture = context.read<SchoolSetupRepository>().hasInitialSetup();
    });
  }
}
