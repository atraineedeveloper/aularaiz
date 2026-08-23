import 'dart:async';
import 'dart:ui';

import 'package:aularaiz/app/app.dart';
import 'package:aularaiz/app/app_dependencies.dart';
import 'package:aularaiz/app/recovery/recovery_failure_app.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/application/backup/restore_models.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/backup/restore_bootstrap_service.dart';
import 'package:aularaiz/infrastructure/backup/restore_runtime_adapter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    SafeLog.frameworkError(details.exception);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    SafeLog.unhandledError(error);
    return true;
  };

  await runZonedGuarded(() async {
    const profile = StorageProfile.production;
    const runtime = RestoreRuntimeAdapter();
    final restoreBootstrap = RestoreBootstrapService(
      profile: profile,
      currentSchemaVersion: AppDatabase.currentSchemaVersion,
      currentSnapshotProvider: () => runtime.createCurrentSnapshot(profile),
      restoredDatabaseOpener: (file) => runtime.openAndMigrate(file, profile),
    );

    try {
      final outcome = await restoreBootstrap.applyPending();
      if (outcome != RestoreBootstrapOutcome.none) {
        SafeLog.recoveryEvent(outcome.name);
      }
    } on RestoreException catch (error) {
      SafeLog.recoveryFailure(error);
      runApp(const RecoveryFailureApp());
      return;
    }

    final settings = await AppSettingsController.load();

    runApp(
      AppDependencies(
        child: ChangeNotifierProvider.value(
          value: settings,
          child: const AulaRaizApp(),
        ),
      ),
    );
  }, (error, stack) => SafeLog.unhandledError(error));
}
