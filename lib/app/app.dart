import 'package:aularaiz/app/accessibility/app_accessibility_frame.dart';
import 'package:aularaiz/app/routing/app_router.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:aularaiz/app/theme/app_theme.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AulaRaizApp extends StatelessWidget {
  const AulaRaizApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    const palette = AppPalette.mexico;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AulaRaizScrollBehavior(),
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      highContrastTheme: AppTheme.highContrastLight(palette),
      highContrastDarkTheme: AppTheme.highContrastDark(palette),
      themeMode: settings.themeMode,
      builder: (context, child) => AppAccessibilityFrame(
        onOpenSettings: () => appRouter.go('/settings'),
        onNavigateBack: () {
          if (appRouter.canPop()) {
            appRouter.pop();
          } else {
            appRouter.go('/');
          }
        },
        child: child ?? const SizedBox.shrink(),
      ),
      routerConfig: appRouter,
    );
  }
}

class _AulaRaizScrollBehavior extends MaterialScrollBehavior {
  const _AulaRaizScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
