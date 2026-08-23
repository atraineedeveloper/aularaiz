import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:flutter/material.dart';

class SchoolSelectionScreen extends StatelessWidget {
  const SchoolSelectionScreen({
    required this.setups,
    required this.onSelect,
    required this.onCreateSchool,
    required this.onOpenSettings,
    super.key,
  });

  final List<InitialSchoolSetup> setups;
  final ValueChanged<String> onSelect;
  final VoidCallback onCreateSchool;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      appBar: AppBar(
        title: Text(english ? 'My schools' : 'Mis escuelas'),
        actions: [
          IconButton(
            tooltip: english ? 'Settings' : 'Preferencias',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onCreateSchool,
        icon: const Icon(Icons.add_rounded),
        label: Text(english ? 'Add school' : 'Agregar escuela'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              children: [
                Text(
                  english ? 'Choose a school' : 'Selecciona una escuela',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  english
                      ? 'AulaRaíz opens the classroom only after you choose its school.'
                      : 'AulaRaíz abre el aula sólo después de que elijas su escuela.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                for (final setup in setups) ...[
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onSelect(setup.school.id),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.school_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    setup.school.name,
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      setup.schoolYear.label,
                                      if (setup.school.cct?.trim().isNotEmpty ==
                                          true)
                                        'CCT ${setup.school.cct}',
                                      if (setup.school.municipality
                                              ?.trim()
                                              .isNotEmpty ==
                                          true)
                                        setup.school.municipality!,
                                    ].join(' · '),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
