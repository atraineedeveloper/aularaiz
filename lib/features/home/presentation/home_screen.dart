import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_controller.dart';
import 'package:aularaiz/features/school_setup/presentation/school_setup_screen.dart';
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

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appName,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.setupCompleteTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.setupCompleteBody,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => context.go('/about'),
                        icon: const Icon(Icons.info_outline),
                        label: Text(l10n.openAbout),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
