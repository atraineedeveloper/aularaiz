import 'dart:async';
import 'dart:ui';

import 'package:aularaiz/app/app.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
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

  await runZonedGuarded(
    () async {
      runApp(
        ChangeNotifierProvider(
          create: (_) => AppSettingsController(),
          child: const AulaRaizApp(),
        ),
      );
    },
    (error, stack) => SafeLog.unhandledError(error),
  );
}
