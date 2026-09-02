import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/school/school_leadership_role.dart';
import 'package:aularaiz/infrastructure/reports/pdf_report_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const attendance = AttendanceReportSummary(
    present: 10,
    absent: 1,
    late: 2,
    justifiedAbsence: 1,
  );
  const evaluation = EvaluationReportSummary(
    pending: 1,
    delivered: 2,
    notDelivered: 1,
    evaluated: 1,
    mastered: 0,
    sufficient: 1,
    inProgress: 0,
    requiresSupport: 0,
  );
  final header = ReportHeader(
    schoolName: 'Primaria de Prueba',
    schoolYearLabel: '2026-2027',
    groupName: '5° A',
    referenceMonth: DateTime(2026, 8),
    cct: '27DPR0000X',
  );
  const student = StudentReportRow(
    studentId: 'student-1',
    displayName: 'Ana López',
    listNumber: 1,
    grade: PrimaryGrade.fifth,
    attendance: attendance,
    evaluation: evaluation,
  );

  test('renders a valid group PDF', () async {
    final bytes = await const PdfReportRenderer().renderGroup(
      GroupReportData(header: header, students: const [student]),
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test(
    'group PDF renders without failing when authority fields are null',
    () async {
      final nullsHeader = ReportHeader(
        schoolName: 'Primaria de Prueba',
        schoolYearLabel: '2026-2027',
        groupName: '5° A',
        referenceMonth: DateTime(2026, 8),
      );
      expect(nullsHeader.schoolZone, isNull);
      expect(nullsHeader.schoolSector, isNull);
      expect(nullsHeader.supervisorName, isNull);
      expect(nullsHeader.leadershipName, isNull);
      expect(nullsHeader.leadershipRole, isNull);
      expect(nullsHeader.teacherName, isNull);

      final bytes = await const PdfReportRenderer().renderGroup(
        GroupReportData(header: nullsHeader, students: const [student]),
      );

      expect(bytes.length, greaterThan(100));
      expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    },
  );

  test('group PDF includes zone, sector, authorities and teacher', () async {
    final fullHeader = ReportHeader(
      schoolName: 'Primaria de Prueba',
      schoolYearLabel: '2026-2027',
      groupName: '5° A',
      referenceMonth: DateTime(2026, 8),
      cct: '27DPR0000X',
      state: 'Tabasco',
      municipality: 'Centro',
      locality: 'Villahermosa',
      schoolZone: 'Zona 045',
      schoolSector: 'Sector 12',
      supervisorName: 'Jorge Villalobos',
      leadershipName: 'María Pérez López',
      leadershipRole: SchoolLeadershipRole.teacherWithLeadership,
      teacherName: 'María Pérez López',
    );

    final spanish = await const PdfReportRenderer().renderGroup(
      GroupReportData(header: fullHeader, students: const [student]),
    );
    expect(spanish.length, greaterThan(100));
    expect(String.fromCharCodes(spanish.take(4)), '%PDF');

    final english = await const PdfReportRenderer(english: true).renderGroup(
      GroupReportData(header: fullHeader, students: const [student]),
    );
    expect(english.length, greaterThan(100));
    expect(String.fromCharCodes(english.take(4)), '%PDF');
  });

  test('renders a valid individual PDF with evaluation semantics', () async {
    final bytes = await const PdfReportRenderer().renderIndividual(
      IndividualReportData(
        header: header,
        student: student,
        evaluations: const [
          EvaluationReportItem(
            activityId: 'activity-1',
            activityTitle: 'Comprensión del cuento',
            deliveryStatus: DeliveryStatus.delivered,
            achievement: AchievementLevel.sufficient,
          ),
          EvaluationReportItem(
            activityId: 'activity-2',
            activityTitle: 'Producto final',
            deliveryStatus: DeliveryStatus.notDelivered,
            achievement: null,
          ),
        ],
        followUp: const [],
      ),
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
