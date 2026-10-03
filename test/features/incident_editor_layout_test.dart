import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/incident_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/core/id/uuid_id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/incidents/presentation/incident_reports_controller.dart';
import 'package:aularaiz/features/incidents/presentation/incident_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  for (final size in [
    const Size(1366, 728),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('incident form remains visible at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_editor());
      await tester.pumpAndSettle();

      final form = tester.getRect(find.byType(Form));
      final save = tester.getRect(
        find.widgetWithText(FilledButton, 'Guardar incidencia'),
      );
      expect(form.height, greaterThan(size.height * 0.3));
      expect(form.bottom, lessThanOrEqualTo(save.top));
      expect(save.bottom, greaterThan(size.height - 80));
      expect(tester.takeException(), isNull);

      final description = find.byType(TextFormField).first;
      await tester.ensureVisible(description);
      await tester.enterText(
        description,
        'Registro de prueba de distribución.',
      );
      await tester.pumpAndSettle();
      expect(find.text('Registro de prueba de distribución.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Seguimiento'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seguimiento'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Se informó a la familia'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('form remains scrollable with the mobile keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(_editor());
    await tester.pumpAndSettle();
    final form = tester.getRect(find.byType(Form));
    expect(form.height, greaterThan(200));
    expect(form.bottom, lessThanOrEqualTo(844 - 280));
    await tester.ensureVisible(find.byType(TextFormField).first);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Hechos registrados.',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _editor() => ChangeNotifierProvider(
  create: (_) => IncidentReportsController(
    incidentRepository: _UnusedIncidentRepository(),
    studentRepository: _UnusedStudentRepository(),
    enrollmentRepository: _UnusedEnrollmentRepository(),
    idGenerator: UuidIdGenerator(),
  ),
  child: MaterialApp(
    locale: Locale('es'),
    supportedLocales: [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: IncidentEditorScreen(
      schoolName: 'Benito Juárez',
      groups: [
        TeachingGroup(
          id: 'class',
          schoolId: 'school',
          schoolYearId: 'year',
          name: 'Grupo multigrado con un nombre largo para comprobar el ancho',
          grades: {PrimaryGrade.first, PrimaryGrade.second},
        ),
      ],
    ),
  ),
);

// The editor reads controller state only; no persistence is used in layout tests.
class _UnusedIncidentRepository implements IncidentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedStudentRepository implements StudentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedEnrollmentRepository implements EnrollmentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
