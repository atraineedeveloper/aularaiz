import 'package:flutter/material.dart';

final class SchoolWorkspaceDestination {
  const SchoolWorkspaceDestination({
    required this.label,
    required this.icon,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelect;
}

class SchoolWorkspaceShell extends StatelessWidget {
  const SchoolWorkspaceShell({
    required this.schoolName,
    required this.schoolYearLabel,
    required this.groupName,
    required this.destinations,
    this.selectedIndex = 0,
    required this.onChooseSchool,
    this.onEditSchool,
    required this.onOpenSettings,
    required this.child,
    super.key,
  });

  final String schoolName;
  final String schoolYearLabel;
  final String groupName;
  final List<SchoolWorkspaceDestination> destinations;
  final int selectedIndex;
  final VoidCallback onChooseSchool;
  final VoidCallback? onEditSchool;
  final VoidCallback onOpenSettings;
  final Widget child;

  static const double _desktopBreakpoint = 980;
  static const double _mobileBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= _desktopBreakpoint &&
            destinations.isNotEmpty;
        final mobile =
            constraints.maxWidth < _mobileBreakpoint && destinations.isNotEmpty;

        return Scaffold(
          appBar: _appBar(showMenu: !desktop && destinations.isNotEmpty),
          drawer: desktop ? null : _drawer(context),
          bottomNavigationBar: mobile && destinations.isNotEmpty
              ? _mobileNavigation(context)
              : null,
          body: SafeArea(
            top: false,
            child: desktop
                ? Row(
                    children: [
                      _navigationRail(context),
                      const VerticalDivider(width: 1),
                      Expanded(child: child),
                    ],
                  )
                : child,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar({required bool showMenu}) {
    return AppBar(
      leading: showMenu
          ? Builder(
              builder: (context) => IconButton(
                tooltip: 'Abrir navegación',
                onPressed: Scaffold.of(context).openDrawer,
                icon: const Icon(Icons.menu_rounded),
              ),
            )
          : null,
      title: _WorkspaceTitle(
        schoolName: schoolName,
        schoolYearLabel: schoolYearLabel,
        groupName: groupName,
      ),
      actions: [
        IconButton(
          tooltip: 'Cambiar escuela',
          onPressed: onChooseSchool,
          icon: const Icon(Icons.swap_horiz_rounded),
        ),
        if (onEditSchool != null)
          IconButton(
            tooltip: 'Editar escuela',
            onPressed: onEditSchool,
            icon: const Icon(Icons.edit_outlined),
          ),
        IconButton(
          tooltip: 'Preferencias',
          onPressed: onOpenSettings,
          icon: const Icon(Icons.tune_rounded),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _navigationRail(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NavigationRail(
      selectedIndex: selectedIndex,
      extended: true,
      minExtendedWidth: 232,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: FilledButton.tonalIcon(
          onPressed: onChooseSchool,
          icon: const Icon(Icons.school_outlined),
          label: const Text('Cambiar escuela'),
        ),
      ),
      trailing: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 208,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_2_outlined,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      groupName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.icon),
            label: Text(destination.label),
          ),
      ],
      onDestinationSelected: (index) => destinations[index].onSelect(),
    );
  }

  Widget _drawer(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
          child: _WorkspaceTitle(
            schoolName: schoolName,
            schoolYearLabel: schoolYearLabel,
            groupName: groupName,
          ),
        ),
        const Divider(),
        for (final destination in destinations)
          NavigationDrawerDestination(
            icon: Icon(destination.icon),
            label: Text(destination.label),
          ),
      ],
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        destinations[index].onSelect();
      },
    );
  }

  Widget _mobileNavigation(BuildContext context) {
    final primary = destinations.take(3).toList(growable: false);
    return NavigationBar(
      selectedIndex: selectedIndex < primary.length ? selectedIndex : 0,
      destinations: [
        for (final destination in primary)
          NavigationDestination(
            icon: Icon(destination.icon),
            label: destination.label,
          ),
        const NavigationDestination(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'Más',
        ),
      ],
      onDestinationSelected: (index) {
        if (index < primary.length) {
          primary[index].onSelect();
          return;
        }
        _showMoreDestinations(context);
      },
    );
  }

  Future<void> _showMoreDestinations(BuildContext context) {
    final remaining = destinations.skip(3).toList(growable: false);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final destination in remaining)
              ListTile(
                leading: Icon(destination.icon),
                title: Text(destination.label),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  destination.onSelect();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceTitle extends StatelessWidget {
  const _WorkspaceTitle({
    required this.schoolName,
    required this.schoolYearLabel,
    required this.groupName,
  });

  final String schoolName;
  final String schoolYearLabel;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(schoolName, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          '$groupName · $schoolYearLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
