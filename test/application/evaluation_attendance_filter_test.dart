import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/domain/attendance/attendance_entry.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/features/evaluation/presentation/evaluation_controller.dart';
import 'package:aularaiz/features/evaluation/presentation/evaluation_screen.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  final group = TeachingGroup(
    id: 'g',
    schoolId: 's',
    schoolYearId: 'y',
    name: '1A',
    grades: {PrimaryGrade.first},
  );
  late EvaluationController controller;
  late _Attendance attendance;
  late _Evaluations evaluations;
  setUp(() async {
    attendance = _Attendance();
    evaluations = _Evaluations();
    final activities = _Activities();
    controller = EvaluationController(
      projectRepository: _Projects(),
      activityRepository: activities,
      studentRepository: _Students(),
      evaluationRepository: evaluations,
      attendanceRepository: attendance,
      saveActivityEvaluation: SaveActivityEvaluation(
        activityRepository: activities,
        evaluationRepository: evaluations,
      ),
    );
    await controller.load(group);
  });
  tearDown(() => controller.dispose());

  test(
    'deleted attendance becomes unrecorded without removing evaluation',
    () async {
      await controller.saveCell(
        activityId: 'a1',
        studentId: 'present',
        deliveryStatus: DeliveryStatus.delivered,
      );
      attendance.deleted = true;
      await controller.load(group);
      expect(controller.hasMissingAttendance('a1'), isTrue);
      expect(controller.visibleMatrixRowsFor('a1'), isEmpty);
      controller.setAttendeesOnly(false);
      expect(
        controller.cell('a1', 'present')!.evaluation.deliveryStatus,
        DeliveryStatus.delivered,
      );
      expect(evaluations.writes, 1);
    },
  );

  for (final width in [400.0, 1200.0]) {
    testWidgets(
      'attendance selector and missing records notice at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              theme: ThemeData(
                brightness: width == 400 ? Brightness.dark : Brightness.light,
              ),
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: EvaluationScreen(group: group),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Asistieron ese día'), findsOneWidget);
        expect(find.textContaining('Falta fecha o asistencia'), findsOneWidget);
        expect(find.text('justified'), findsNothing);
        await tester.tap(find.text('Todos'));
        await tester.pumpAndSettle();
        expect(controller.attendeesOnly, isFalse);
        expect(find.text('justified'), findsWidgets);
        expect(evaluations.writes, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('filters each date independently and includes late students', () {
    expect(controller.error, isNull);
    expect(controller.visibleMatrixRowsFor('a1').map((r) => r.studentId), [
      'late',
      'present',
    ]);
    expect(controller.visibleMatrixRowsFor('a2').map((r) => r.studentId), [
      'absent',
    ]);
    expect(controller.isVisibleForActivity('a1', 'absent'), isFalse);
    expect(controller.isVisibleForActivity('a1', 'justified'), isFalse);
    expect(
      controller.cell('a1', 'absent')!.evaluation.deliveryStatus,
      DeliveryStatus.pending,
    );
    expect(evaluations.writes, 0);
  });

  test(
    'missing entries, missing day and undated activity are not attendance',
    () {
      expect(controller.hasMissingAttendance('a1'), isTrue);
      expect(controller.visibleMatrixRowsFor('a3'), isEmpty);
      expect(controller.visibleMatrixRowsFor('undated'), isEmpty);
      expect(controller.hasMissingAttendance('a3'), isTrue);
      controller.setAttendeesOnly(false);
      expect(controller.visibleMatrixRowsFor('a3'), hasLength(5));
      expect(controller.visibleMatrixRowsFor('undated'), hasLength(5));
      expect(evaluations.writes, 0);
    },
  );

  test(
    'Everyone permits make-up work and filtering preserves that evaluation',
    () async {
      controller.setAttendeesOnly(false);
      expect(
        await controller.saveCell(
          activityId: 'a1',
          studentId: 'absent',
          deliveryStatus: DeliveryStatus.delivered,
        ),
        isTrue,
      );
      controller.setAttendeesOnly(true);
      expect(controller.isVisibleForActivity('a1', 'absent'), isFalse);
      expect(
        controller.cell('a1', 'absent')!.evaluation.deliveryStatus,
        DeliveryStatus.delivered,
      );
      expect(evaluations.writes, 1);
    },
  );

  test(
    'refresh reads corrected attendance and preserves activity selection',
    () async {
      await controller.selectActivity('a2');
      attendance.corrected = true;
      await controller.load(group);
      expect(controller.selected!.activity.id, 'a2');
      expect(controller.isVisibleForActivity('a1', 'absent'), isTrue);
      expect(evaluations.writes, 0);
    },
  );
}

class _Attendance implements AttendanceRepository {
  bool deleted = false;
  bool corrected = false;
  @override
  Future<DailyAttendance?> findByGroupAndDate(
    String groupId,
    DateTime date,
  ) async {
    if (deleted || date.day == 3) return null;
    return DailyAttendance(
      id: 'day-${date.day}',
      groupId: groupId,
      date: date,
      entries: [
        AttendanceEntry(
          studentId: 'present',
          status: date.day == 1
              ? AttendanceStatus.present
              : AttendanceStatus.absent,
        ),
        AttendanceEntry(
          studentId: 'late',
          status: date.day == 1
              ? AttendanceStatus.late
              : AttendanceStatus.absent,
        ),
        AttendanceEntry(
          studentId: 'absent',
          status: corrected || date.day == 2
              ? AttendanceStatus.present
              : AttendanceStatus.absent,
        ),
        AttendanceEntry(
          studentId: 'justified',
          status: AttendanceStatus.justifiedAbsence,
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Activities implements ActivityRepository {
  final activities = [
    for (var day = 1; day <= 4; day++)
      Activity(
        id: day == 4 ? 'undated' : 'a$day',
        projectId: 'p',
        title: 'Activity $day',
        occursOn: day == 4 ? null : DateTime(2026, 9, day),
        formativeField: FormativeField.languages,
        targetGrades: {PrimaryGrade.first},
        roster: [
          for (final id in [
            'present',
            'late',
            'absent',
            'justified',
            'unknown',
          ])
            ActivityParticipant(studentId: id, grade: PrimaryGrade.first),
        ],
      ),
  ];
  @override
  Future<List<Activity>> listForProject(String projectId) async => activities;
  @override
  Future<Activity?> findById(String id) async =>
      activities.where((a) => a.id == id).firstOrNull;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Projects implements ProjectRepository {
  @override
  Future<List<Project>> listForGroup(String groupId) async => [
    Project(
      id: 'p',
      groupId: groupId,
      title: 'Project',
      lifecycle: ProjectLifecycle.values.first,
      methodology: ProjectMethodology.unspecified,
      targetGrades: {PrimaryGrade.first},
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Students implements StudentRepository {
  @override
  Future<Student?> findById(String id) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Evaluations implements EvaluationRepository {
  int writes = 0;
  final saved = <ActivityEvaluation>[];
  @override
  Future<List<ActivityEvaluation>> listForActivity(String activityId) async =>
      saved.where((e) => e.activityId == activityId).toList();
  @override
  Future<void> save(ActivityEvaluation evaluation) async {
    writes++;
    saved.add(evaluation);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
