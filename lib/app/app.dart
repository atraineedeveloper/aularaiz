import 'package:aularaiz/app/routing/app_router.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/app/theme/app_theme.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AulaRaizApp extends StatelessWidget {
  const AulaRaizApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(settings.palette),
      darkTheme: AppTheme.dark(settings.palette),
      highContrastTheme: AppTheme.highContrastLight(settings.palette),
      highContrastDarkTheme: AppTheme.highContrastDark(settings.palette),
      themeMode: settings.themeMode,
      routerConfig: appRouter,
    );
  }
}
