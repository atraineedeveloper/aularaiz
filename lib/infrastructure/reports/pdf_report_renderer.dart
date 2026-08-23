import 'dart:typed_data';

import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final class PdfReportRenderer {
  const PdfReportRenderer({this.english = false});

  final bool english;

  Future<Uint8List> renderGroup(GroupReportData report) async {
    final labels = _Labels(english);
    final document = pw.Document(
      title: 'AulaRaíz report',
      creator: 'AulaRaíz',
      subject: 'Classroom report',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (_) => _header(report.header, labels, labels.groupReport),
        footer: (context) => _footer(context, labels),
        build: (_) => [
          pw.SizedBox(height: 14),
          pw.Text(
            labels.groupSummaryNote,
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          _groupTable(report.students, labels),
        ],
      ),
    );

    return document.save();
  }

  Future<Uint8List> renderIndividual(IndividualReportData report) async {
    final labels = _Labels(english);
    final document = pw.Document(
      title: 'AulaRaíz report',
      creator: 'AulaRaíz',
      subject: 'Student report',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _header(report.header, labels, labels.individualReport),
        footer: (context) => _footer(context, labels),
        build: (_) => [
          pw.SizedBox(height: 14),
          _studentIdentity(report.student, labels),
          pw.SizedBox(height: 16),
          _sectionTitle(labels.attendance),
          pw.SizedBox(height: 6),
          _attendanceSummary(report.student.attendance, labels),
          pw.SizedBox(height: 16),
          _sectionTitle(labels.evaluation),
          pw.SizedBox(height: 6),
          _evaluationSummary(report.student.evaluation, labels),
          pw.SizedBox(height: 10),
          _evaluationTable(report.evaluations, labels),
          if (_hasProfile(report.student)) ...[
            pw.SizedBox(height: 16),
            _sectionTitle(labels.pedagogicalProfile),
            pw.SizedBox(height: 6),
            _profile(report.student, labels),
          ],
          if (report.followUp.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _sectionTitle(labels.followUp),
            pw.SizedBox(height: 6),
            ...report.followUp.map((item) => _followUpItem(item, labels)),
          ],
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _header(ReportHeader header, _Labels labels, String title) {
    final place = <String>[
      if (header.locality != null) header.locality!,
      if (header.municipality != null) header.municipality!,
      if (header.state != null) header.state!,
    ].join(', ');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'AulaRaíz',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  _monthLabel(header.referenceMonth, english),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  header.schoolYearLabel,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          header.schoolName,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '${labels.group}: ${header.groupName}'
          '${header.cct == null ? '' : ' · CCT ${header.cct}'}',
          style: const pw.TextStyle(fontSize: 9),
        ),
        if (place.isNotEmpty)
          pw.Text(place, style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 6),
        pw.Divider(height: 1),
      ],
    );
  }

  pw.Widget _footer(pw.Context context, _Labels labels) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text(
        '${labels.page} ${context.pageNumber} ${labels.of} ${context.pagesCount}',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    );
  }

  pw.Widget _studentIdentity(StudentReportRow student, _Labels labels) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              student.displayName,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            '${labels.listNumber}: ${student.listNumber} · '
            '${labels.grade}: ${student.grade.number}°',
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    );
  }

  pw.Widget _attendanceSummary(
    AttendanceReportSummary summary,
    _Labels labels,
  ) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metric(labels.present, summary.present.toString()),
        _metric(labels.absent, summary.absent.toString()),
        _metric(labels.late, summary.late.toString()),
        _metric(labels.justified, summary.justifiedAbsence.toString()),
        _metric(labels.markedDays, summary.totalMarked.toString()),
      ],
    );
  }

  pw.Widget _evaluationSummary(
    EvaluationReportSummary summary,
    _Labels labels,
  ) {
    final compliance = summary.deliveryCompliance;
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metric(labels.delivered, summary.delivered.toString()),
        _metric(labels.notDelivered, summary.notDelivered.toString()),
        _metric(labels.pending, summary.pending.toString()),
        _metric(labels.evaluated, summary.evaluated.toString()),
        _metric(
          labels.compliance,
          compliance == null ? '—' : '${(compliance * 100).round()}%',
        ),
      ],
    );
  }

  pw.Widget _metric(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text('$label: ', style: const pw.TextStyle(fontSize: 8)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _groupTable(List<StudentReportRow> students, _Labels labels) {
    final rows = <List<String>>[
      [
        '#',
        labels.student,
        labels.grade,
        labels.present,
        labels.absent,
        labels.late,
        labels.justified,
        labels.delivered,
        labels.notDelivered,
        labels.pending,
        labels.evaluated,
      ],
      for (final student in students)
        [
          student.listNumber.toString(),
          student.displayName,
          '${student.grade.number}°',
          student.attendance.present.toString(),
          student.attendance.absent.toString(),
          student.attendance.late.toString(),
          student.attendance.justifiedAbsence.toString(),
          student.evaluation.delivered.toString(),
          student.evaluation.notDelivered.toString(),
          student.evaluation.pending.toString(),
          student.evaluation.evaluated.toString(),
        ],
    ];
    return _textTable(rows, headerColumns: rows.first.length, fontSize: 7.5);
  }

  pw.Widget _evaluationTable(List<EvaluationReportItem> items, _Labels labels) {
    if (items.isEmpty) {
      return pw.Text(
        labels.noEvaluations,
        style: const pw.TextStyle(fontSize: 9),
      );
    }
    final rows = <List<String>>[
      [
        labels.activity,
        labels.delivery,
        labels.achievement,
        labels.observation,
      ],
      for (final item in items)
        [
          item.activityTitle,
          _deliveryLabel(item.deliveryStatus, labels),
          _achievementLabel(item.achievement, labels),
          item.observation ?? '—',
        ],
    ];
    return _textTable(rows, headerColumns: rows.first.length, fontSize: 8);
  }

  pw.Widget _profile(StudentReportRow student, _Labels labels) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _labeledText(labels.strengths, student.strengths),
        _labeledText(labels.difficulties, student.difficulties),
        _labeledText(labels.supports, student.supports),
      ],
    );
  }

  pw.Widget _labeledText(String label, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: value ?? '—'),
          ],
        ),
      ),
    );
  }

  pw.Widget _followUpItem(ReportFollowUpItem item, _Labels labels) {
    final kind = item.kind == StudentRecordEntryKind.observation
        ? labels.observation
        : labels.familyAgreement;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 7),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$kind · ${_dateLabel(item.occurredAt)}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(item.text, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _textTable(
    List<List<String>> rows, {
    required int headerColumns,
    required double fontSize,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
          pw.TableRow(
            decoration: rowIndex == 0
                ? const pw.BoxDecoration(color: PdfColors.grey200)
                : null,
            children: [
              for (var column = 0; column < headerColumns; column++)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    rows[rowIndex][column],
                    style: pw.TextStyle(
                      fontSize: fontSize,
                      fontWeight: rowIndex == 0 ? pw.FontWeight.bold : null,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  bool _hasProfile(StudentReportRow student) {
    return student.strengths != null ||
        student.difficulties != null ||
        student.supports != null;
  }

  String _deliveryLabel(DeliveryStatus status, _Labels labels) {
    return switch (status) {
      DeliveryStatus.pending => labels.pending,
      DeliveryStatus.delivered => labels.delivered,
      DeliveryStatus.notDelivered => labels.notDelivered,
    };
  }

  String _achievementLabel(AchievementLevel? level, _Labels labels) {
    return switch (level) {
      AchievementLevel.mastered => labels.mastered,
      AchievementLevel.sufficient => labels.sufficient,
      AchievementLevel.inProgress => labels.inProgress,
      AchievementLevel.requiresSupport => labels.requiresSupport,
      null => '—',
    };
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year}';
  }
}

String _monthLabel(DateTime month, bool english) {
  const es = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  const en = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final names = english ? en : es;
  final name = names[month.month - 1];
  return english
      ? '$name ${month.year}'
      : '${name[0].toUpperCase()}${name.substring(1)} ${month.year}';
}

final class _Labels {
  const _Labels(this.english);

  final bool english;

  String get individualReport =>
      english ? 'Individual report' : 'Reporte individual';
  String get groupReport => english ? 'Group report' : 'Reporte grupal';
  String get group => english ? 'Group' : 'Grupo';
  String get page => english ? 'Page' : 'Página';
  String get of => english ? 'of' : 'de';
  String get listNumber => english ? 'List no.' : 'N. de lista';
  String get grade => english ? 'Grade' : 'Grado';
  String get student => english ? 'Student' : 'Alumno';
  String get attendance => english ? 'Attendance' : 'Asistencia';
  String get evaluation => english ? 'Evaluation' : 'Evaluación';
  String get present => english ? 'Present' : 'Presente';
  String get absent => english ? 'Absent' : 'Ausente';
  String get late => english ? 'Late' : 'Retardo';
  String get justified => english ? 'Justified' : 'Justificada';
  String get markedDays => english ? 'Marked days' : 'Días registrados';
  String get delivered => english ? 'Delivered' : 'Entregó';
  String get notDelivered => english ? 'Not delivered' : 'No entregó';
  String get pending => english ? 'Pending' : 'Pendiente';
  String get evaluated => english ? 'Evaluated' : 'Evaluado';
  String get compliance => english ? 'Delivery compliance' : 'Cumplimiento';
  String get activity => english ? 'Activity' : 'Actividad';
  String get delivery => english ? 'Delivery' : 'Entrega';
  String get achievement => english ? 'Achievement' : 'Logro';
  String get observation => english ? 'Observation' : 'Observación';
  String get noEvaluations => english
      ? 'No applicable activities for this student.'
      : 'No hay actividades aplicables para este alumno.';
  String get pedagogicalProfile =>
      english ? 'Pedagogical profile' : 'Perfil pedagógico';
  String get strengths => english ? 'Strengths' : 'Fortalezas';
  String get difficulties => english ? 'Difficulties' : 'Dificultades';
  String get supports =>
      english ? 'Supports and adjustments' : 'Apoyos y ajustes';
  String get followUp =>
      english ? 'Chronological follow-up' : 'Seguimiento cronológico';
  String get familyAgreement =>
      english ? 'Family agreement' : 'Acuerdo familiar';
  String get mastered => english ? 'Mastered' : 'Dominado';
  String get sufficient => english ? 'Sufficient' : 'Suficiente';
  String get inProgress => english ? 'In progress' : 'En proceso';
  String get requiresSupport => english ? 'Requires support' : 'Requiere apoyo';
  String get groupSummaryNote => english
      ? 'Attendance and evaluation are kept as separate evidence. Non-delivery is not an achievement level.'
      : 'Asistencia y evaluación se conservan como evidencias separadas. No entregar no equivale a un nivel de logro.';
}
