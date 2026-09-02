import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/features/settings/presentation/backup_restore_section.dart';
import 'package:aularaiz/features/settings/presentation/teacher_profile_section.dart';
import 'package:aularaiz/features/settings/presentation/update_section.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<AppSettingsController>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Icon(
                              Icons.tune_rounded,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.settingsTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? 'Manage how AulaRaíz works on this device.'
                                    : 'Administra cómo funciona AulaRaíz en este dispositivo.',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  icon: Icons.language_rounded,
                  title: l10n.language,
                  child: SegmentedButton<String>(
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'es',
                        label: Text(l10n.languageSpanish),
                        icon: const Icon(Icons.translate_rounded),
                      ),
                      ButtonSegment<String>(
                        value: 'en',
                        label: Text(l10n.languageEnglish),
                        icon: const Icon(Icons.language_rounded),
                      ),
                    ],
                    selected: <String>{settings.locale.languageCode},
                    onSelectionChanged: (selection) {
                      settings.setLocale(Locale(selection.single));
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _SettingsSection(
                  icon: Icons.contrast_rounded,
                  title: l10n.appearance,
                  child: SegmentedButton<ThemeMode>(
                    segments: <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text(l10n.themeSystem),
                        icon: const Icon(Icons.settings_suggest_outlined),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text(l10n.themeLight),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text(l10n.themeDark),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: <ThemeMode>{settings.themeMode},
                    onSelectionChanged: (selection) {
                      settings.setThemeMode(selection.single);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const TeacherProfileSection(),
                const SizedBox(height: 20),
                const BackupRestoreSection(),
                const SizedBox(height: 20),
                const UpdateSection(),
                if (SafeLog.filePath != null) ...[
                  const SizedBox(height: 20),
                  _SettingsSection(
                    icon: Icons.bug_report_outlined,
                    title: Localizations.localeOf(context).languageCode == 'en'
                        ? 'Diagnostics'
                        : 'Diagnóstico',
                    child: SelectableText(
                      SafeLog.filePath!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, color: scheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}
