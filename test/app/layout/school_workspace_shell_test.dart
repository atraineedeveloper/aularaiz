import 'package:aularaiz/app/layout/school_workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses a persistent navigation rail on desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_shell());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Alumnos'), findsOneWidget);
  });

  testWidgets('uses bottom navigation on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_shell());

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);
  });
}

Widget _shell() {
  return MaterialApp(
    home: SchoolWorkspaceShell(
      schoolName: 'Primaria Benito Juárez',
      schoolYearLabel: '2026–2027',
      groupName: '5.º A',
      onChooseSchool: () {},
      onOpenSettings: () {},
      destinations: [
        SchoolWorkspaceDestination(
          label: 'Inicio',
          icon: Icons.home_outlined,
          onSelect: () {},
        ),
        SchoolWorkspaceDestination(
          label: 'Alumnos',
          icon: Icons.groups_outlined,
          onSelect: () {},
        ),
        SchoolWorkspaceDestination(
          label: 'Asistencia',
          icon: Icons.fact_check_outlined,
          onSelect: () {},
        ),
        SchoolWorkspaceDestination(
          label: 'Proyectos',
          icon: Icons.auto_awesome_motion_outlined,
          onSelect: () {},
        ),
      ],
      child: const Center(child: Text('Contenido del grupo')),
    ),
  );
}
