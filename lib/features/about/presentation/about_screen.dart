import 'package:aularaiz/app/layout/responsive_layout.dart';
import 'package:aularaiz/infrastructure/window/window_title_service.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layout = ResponsiveLayoutInfo.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowTitleService.setTitle('AulaRaíz · ${l10n.openAbout}');
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(layout.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.aboutBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: layout.preferDenseUi ? 12 : 24),
              OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back),
                label: Text(l10n.back),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
