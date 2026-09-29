import 'dart:async';
import 'dart:io';

import 'package:aularaiz/app/accessibility/app_accessibility_frame.dart';
import 'package:aularaiz/app/routing/app_router.dart';
import 'package:aularaiz/app/runtime/app_runtime_config.dart';
import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:aularaiz/app/theme/app_theme.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

class AulaRaizApp extends StatefulWidget {
  const AulaRaizApp({super.key});

  @override
  State<AulaRaizApp> createState() => _AulaRaizAppState();
}

class _AulaRaizAppState extends State<AulaRaizApp> {
  StreamSubscription<Uri?>? _widgetClickSubscription;
  String? _lastWidgetUri;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) return;
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(
      _handleWidgetLaunch,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_checkInitialWidgetLaunch());
    });
  }

  @override
  void dispose() {
    unawaited(_widgetClickSubscription?.cancel());
    super.dispose();
  }

  Future<void> _checkInitialWidgetLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (mounted) _handleWidgetLaunch(uri);
    } catch (_) {
      // Widget launch support must not interrupt normal startup.
    }
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri == null || uri.toString() == _lastWidgetUri) return;
    final action = uri.queryParameters['action'];
    if (!const {'arrival', 'departure', 'open'}.contains(action)) return;
    _lastWidgetUri = uri.toString();
    final schoolId = uri.queryParameters['schoolId'];
    final path = '/widget/teacher-attendance/$action';
    final query = schoolId == null || schoolId.isEmpty
        ? ''
        : '?schoolId=${Uri.encodeQueryComponent(schoolId)}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) appRouter.go('$path$query');
    });
    Timer(const Duration(seconds: 2), () => _lastWidgetUri = null);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsController>();
    final runtime =
        context.watch<AppRuntimeConfig?>() ??
        const AppRuntimeConfig.production();
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
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onTertiaryContainer,
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
