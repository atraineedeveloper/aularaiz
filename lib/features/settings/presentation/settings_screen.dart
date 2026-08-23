import 'package:aularaiz/app/settings/app_settings_controller.dart';
import 'package:aularaiz/app/theme/app_palette.dart';
import 'package:aularaiz/features/settings/presentation/backup_restore_section.dart';
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
                  icon: Icons.palette_outlined,
                  title: l10n.colorPalette,
                  subtitle: l10n.paletteDescription,
                  child: Column(
                    children: [
                      _PaletteTile(
                        palette: AppPalette.government2024,
                        title: l10n.palette2024,
                        selected: settings.palette == AppPalette.government2024,
                        onTap: () =>
                            settings.setPalette(AppPalette.government2024),
                      ),
                      const SizedBox(height: 12),
                      _PaletteTile(
                        palette: AppPalette.government2018,
                        title: l10n.palette2018,
                        selected: settings.palette == AppPalette.government2018,
                        onTap: () =>
                            settings.setPalette(AppPalette.government2018),
                      ),
                    ],
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
                const BackupRestoreSection(),
                const SizedBox(height: 20),
                const UpdateSection(),
                const SizedBox(height: 20),
                _SettingsSection(
                  icon: Icons.text_fields_rounded,
                  title: l10n.typography,
                  child: Text(
                    'Montserrat',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
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
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
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

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.palette,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final color in palette.swatches)
                              Container(
                                width: 34,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
