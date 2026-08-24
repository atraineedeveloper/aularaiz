import 'package:aularaiz/app/accessibility/app_accessibility_frame.dart';
import 'package:aularaiz/app/routing/app_router.dart';
import 'package:aularaiz/app/runtime/app_runtime_config.dart';
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
    final runtime = context.watch<AppRuntimeConfig>();
    const palette = AppPalette.mexico;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _AulaRaizScrollBehavior(),
      onGenerateTitle: (context) {
        final name = AppLocalizations.of(context).appName;
        return runtime.isDemo ? '$name · DEMO' : name;
      },
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      highContrastTheme: AppTheme.highContrastLight(palette),
      highContrastDarkTheme: AppTheme.highContrastDark(palette),
      themeMode: settings.themeMode,
      builder: (context, child) {
        final content = AppAccessibilityFrame(
          onOpenSettings: () => appRouter.go('/settings'),
          onNavigateBack: () {
            if (appRouter.canPop()) {
              appRouter.pop();
            } else {
              appRouter.go('/');
            }
          },
          child: child ?? const SizedBox.shrink(),
        );
        if (!runtime.isDemo) return content;

        return Stack(
          children: [
            content,
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IgnorePointer(
                  child: Semantics(
                    label: 'DEMO',
                    child: Material(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(999),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          'DEMO',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
