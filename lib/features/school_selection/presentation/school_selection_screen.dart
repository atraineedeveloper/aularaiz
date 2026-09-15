import 'package:aularaiz/app/layout/responsive_layout.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:flutter/material.dart';

class SchoolSelectionScreen extends StatelessWidget {
  const SchoolSelectionScreen({
    required this.setups,
    required this.onSelect,
    required this.onDeleteSchool,
    required this.onCreateSchool,
    required this.onOpenSettings,
    super.key,
  });

  final List<InitialSchoolSetup> setups;
  final ValueChanged<String> onSelect;
  final Future<void> Function(String schoolId) onDeleteSchool;
  final VoidCallback onCreateSchool;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final copy = _SchoolSelectionCopy(
      english: Localizations.localeOf(context).languageCode == 'en',
    );
    final layout = ResponsiveLayoutInfo.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(copy.title),
        actions: [
          IconButton(
            tooltip: copy.settings,
            onPressed: onOpenSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: _FloatingCreateButton(
        label: copy.addSchool,
        compact: layout.isPhoneLandscape,
        onPressed: onCreateSchool,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 720;
            final dense = layout.preferDenseUi;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 32 : layout.pagePadding,
                    dense ? 12 : 28,
                    desktop ? 32 : layout.pagePadding,
                    desktop ? 32 : (dense ? 72 : 104),
                  ),
                  itemCount: setups.length + 1,
                  separatorBuilder: (_, index) =>
                      SizedBox(height: index == 0 ? 20 : 12),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _SchoolSelectionHeader(
                        copy: copy,
                        schoolCount: setups.length,
                        desktop: desktop,
                        dense: dense,
                        onCreateSchool: onCreateSchool,
                      );
                    }

                    final setup = setups[index - 1];
                    return _SchoolCard(
                      setup: setup,
                      copy: copy,
                      dense: dense,
                      onSelect: () => onSelect(setup.school.id),
                      onDelete: () => _confirmDelete(context, setup),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    InitialSchoolSetup setup,
  ) async {
    final copy = _SchoolSelectionCopy(
      english: Localizations.localeOf(context).languageCode == 'en',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(copy.deleteSchoolQuestion),
        content: Text(copy.deleteSchoolBody(setup.school.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(copy.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(copy.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await onDeleteSchool(setup.school.id);
  }
}

class _SchoolSelectionHeader extends StatelessWidget {
  const _SchoolSelectionHeader({
    required this.copy,
    required this.schoolCount,
    required this.desktop,
    required this.dense,
    required this.onCreateSchool,
  });

  final _SchoolSelectionCopy copy;
  final int schoolCount;
  final bool desktop;
  final bool dense;
  final VoidCallback onCreateSchool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: desktop ? 4 : 0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(copy.title, style: theme.textTheme.headlineMedium),
                if (!dense) ...[
                  const SizedBox(height: 6),
                  Text(copy.subtitle, style: theme.textTheme.bodyLarge),
                ],
                SizedBox(height: dense ? 8 : 12),
                Chip(
                  avatar: const Icon(Icons.school_outlined, size: 18),
                  label: Text(copy.schoolCount(schoolCount)),
                ),
              ],
            ),
          ),
          if (desktop)
            FilledButton.icon(
              onPressed: onCreateSchool,
              icon: const Icon(Icons.add_rounded),
              label: Text(copy.addSchool),
            ),
        ],
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.setup,
    required this.copy,
    required this.dense,
    required this.onSelect,
    required this.onDelete,
  });

  final InitialSchoolSetup setup;
  final _SchoolSelectionCopy copy;
  final bool dense;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final school = setup.school;
    final details = <String>[
      setup.schoolYear.label,
      if (school.cct != null) 'CCT ${school.cct}',
      if (school.municipality != null) school.municipality!,
    ];
    final chips = <String>[
      _organizationLabel(school.organization, copy),
      if (school.schoolZone != null) '${copy.zone}: ${school.schoolZone}',
      if (school.schoolSector != null) '${copy.sector}: ${school.schoolSector}',
    ].where((item) => item.trim().isNotEmpty).toList(growable: false);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: EdgeInsets.all(dense ? 14 : 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      school.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details.join(' · '),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (chips.isNotEmpty && !dense) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final chip in chips)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(chip),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_SchoolAction>(
                tooltip: copy.moreActions,
                onSelected: (action) {
                  switch (action) {
                    case _SchoolAction.open:
                      onSelect();
                    case _SchoolAction.delete:
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _SchoolAction.open,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.login_rounded),
                      title: Text(copy.openSchool),
                    ),
                  ),
                  PopupMenuItem(
                    value: _SchoolAction.delete,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        copy.deleteSchool,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingCreateButton extends StatelessWidget {
  const _FloatingCreateButton({
    required this.label,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 720) {
      return const SizedBox.shrink();
    }
    if (compact) {
      return FloatingActionButton(
        onPressed: onPressed,
        tooltip: label,
        child: const Icon(Icons.add_rounded),
      );
    }
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded),
      label: Text(label),
    );
  }
}

enum _SchoolAction { open, delete }

final class _SchoolSelectionCopy {
  const _SchoolSelectionCopy({required this.english});

  final bool english;

  String get title => english ? 'My schools' : 'Mis escuelas';
  String get subtitle => english
      ? 'Select the school and school year you want to work with.'
      : 'Elige la escuela y el ciclo escolar con el que quieres trabajar.';
  String get settings => english ? 'Settings' : 'Preferencias';
  String get addSchool => english ? 'Add school' : 'Agregar escuela';
  String get openSchool => english ? 'Open school' : 'Entrar a la escuela';
  String get deleteSchool => english ? 'Delete school' : 'Eliminar escuela';
  String get moreActions => english ? 'More actions' : 'Más acciones';
  String get cancel => english ? 'Cancel' : 'Cancelar';
  String get delete => english ? 'Delete' : 'Eliminar';
  String get deleteSchoolQuestion =>
      english ? 'Delete school?' : '¿Eliminar escuela?';
  String get zone => english ? 'Zone' : 'Zona';
  String get sector => english ? 'Sector' : 'Sector';

  String schoolCount(int count) => english
      ? '$count ${count == 1 ? 'school' : 'schools'}'
      : '$count ${count == 1 ? 'escuela' : 'escuelas'}';

  String deleteSchoolBody(String schoolName) => english
      ? 'This will permanently delete "$schoolName", its class, attendance, projects, activities and evaluations. This action cannot be undone.'
      : 'Se eliminará permanentemente "$schoolName", su grupo, asistencias, proyectos, actividades y evaluaciones. Esta acción no se puede deshacer.';
}

String _organizationLabel(
  SchoolOrganization organization,
  _SchoolSelectionCopy copy,
) {
  return switch (organization) {
    SchoolOrganization.unspecified => '',
    SchoolOrganization.unitary => copy.english ? 'One-teacher' : 'Unitaria',
    SchoolOrganization.twoTeacher => copy.english ? 'Two-teacher' : 'Bidocente',
    SchoolOrganization.threeTeacher =>
      copy.english ? 'Three-teacher' : 'Tridocente',
    SchoolOrganization.fourTeacher =>
      copy.english ? 'Four-teacher' : 'Tetradocente',
    SchoolOrganization.fiveTeacher =>
      copy.english ? 'Five-teacher' : 'Pentadocente',
    SchoolOrganization.complete => copy.english ? 'Complete' : 'Completa',
  };
}
