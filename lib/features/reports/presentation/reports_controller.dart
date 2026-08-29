import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/application/reports/report_projection_builder.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/infrastructure/reports/group_export_renderer.dart';
import 'package:aularaiz/infrastructure/reports/pdf_report_renderer.dart';
import 'package:aularaiz/infrastructure/reports/report_publication_service.dart';
import 'package:flutter/foundation.dart';

export 'package:aularaiz/features/reports/presentation/reports_localization.dart';
export 'package:aularaiz/infrastructure/reports/group_export_renderer.dart'
    show GroupExportDataset, GroupExportFormat;

enum ReportPublishResult { published, cancelled, failed }

final class ReportsController extends ChangeNotifier {
  ReportsController({
    required ReportProjectionBuilder projectionBuilder,
    required ReportPublicationService publicationService,
  }) : _projectionBuilder = projectionBuilder,
       _publicationService = publicationService;

  final ReportProjectionBuilder _projectionBuilder;
  final ReportPublicationService _publicationService;

  TeachingGroup? _group;
  DateTime _referenceMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  GroupReportData? _groupReport;
  bool _includeSensitiveFollowUp = false;
  bool _isLoading = false;
  bool _isPublishing = false;
  Object? _error;

  TeachingGroup? get group => _group;
  DateTime get referenceMonth => _referenceMonth;
  GroupReportData? get groupReport => _groupReport;
  bool get includeSensitiveFollowUp => _includeSensitiveFollowUp;
  bool get isLoading => _isLoading;
  bool get isPublishing => _isPublishing;
  Object? get error => _error;

  Future<void> load(TeachingGroup group) async {
    _group = group;
    await _reloadGroupReport();
  }

  Future<void> previousMonth() async {
    _referenceMonth = DateTime(_referenceMonth.year, _referenceMonth.month - 1);
    await _reloadGroupReport();
  }

  Future<void> nextMonth() async {
    _referenceMonth = DateTime(_referenceMonth.year, _referenceMonth.month + 1);
    await _reloadGroupReport();
  }

  void setSensitiveFollowUp(bool value) {
    if (_includeSensitiveFollowUp == value) return;
    _includeSensitiveFollowUp = value;
    notifyListeners();
  }

  Future<ReportPublishResult> publishGroup({required bool english}) async {
    final group = _group;
    if (group == null || _isPublishing) return ReportPublishResult.failed;
    return _publish(() async {
      final report = await _projectionBuilder.buildGroup(
        group: group,
        referenceMonth: _referenceMonth,
        privacy: ReportPrivacyOptions(
          includeSensitiveFollowUp: _includeSensitiveFollowUp,
        ),
      );
      final bytes = await PdfReportRenderer(english: english)
          .renderGroup(report);
      return _publicationService.publishPdf(
        bytes: bytes,
        fileName: 'aularaiz-reporte-grupal-${_monthKey()}.pdf',
      );
    });
  }

  Future<ReportPublishResult> publishGroupExport({
    required GroupExportFormat format,
    required bool english,
    GroupExportDataset dataset = GroupExportDataset.students,
  }) async {
    final group = _group;
    if (group == null || _isPublishing) return ReportPublishResult.failed;
    return _publish(() async {
      final data = await _projectionBuilder.buildGroupExport(
        group: group,
        referenceMonth: _referenceMonth,
        privacy: ReportPrivacyOptions(
          includeSensitiveFollowUp: _includeSensitiveFollowUp,
        ),
      );
      final renderer = GroupExportRenderer(english: english);

      return switch (format) {
        GroupExportFormat.csv => _publicationService.publishFile(
          bytes: renderer.renderCsv(data, dataset: dataset),
          fileName: 'aularaiz-${dataset.name.toLowerCase()}-${_monthKey()}.csv',
          mimeType: 'text/csv',
          extension: 'csv',
          typeLabel: 'CSV',
        ),
        GroupExportFormat.xlsx => _publicationService.publishFile(
          bytes: renderer.renderXlsx(data),
          fileName: 'aularaiz-grupo-completo-${_monthKey()}.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          extension: 'xlsx',
          typeLabel: 'Excel',
        ),
      };
    });
  }

  Future<ReportPublishResult> publishIndividual({
    required String studentId,
    required bool english,
  }) async {
    final group = _group;
    if (group == null || _isPublishing) return ReportPublishResult.failed;
    return _publish(() async {
      final report = await _projectionBuilder.buildIndividual(
        group: group,
        studentId: studentId,
        referenceMonth: _referenceMonth,
        privacy: ReportPrivacyOptions(
          includeSensitiveFollowUp: _includeSensitiveFollowUp,
        ),
      );
      final bytes = await PdfReportRenderer(english: english)
          .renderIndividual(report);
      return _publicationService.publishPdf(
        bytes: bytes,
        fileName: 'aularaiz-reporte-individual-${_monthKey()}.pdf',
      );
    });
  }

  Future<void> _reloadGroupReport() async {
    final group = _group;
    if (group == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _groupReport = await _projectionBuilder.buildGroup(
        group: group,
        referenceMonth: _referenceMonth,
      );
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('load_reports', error);
      _groupReport = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ReportPublishResult> _publish(
    Future<bool> Function() operation,
  ) async {
    _isPublishing = true;
    _error = null;
    notifyListeners();
    try {
      final published = await operation();
      if (published) SafeLog.operationSuccess('publish_report');
      return published
          ? ReportPublishResult.published
          : ReportPublishResult.cancelled;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('publish_report', error);
      return ReportPublishResult.failed;
    } finally {
      _isPublishing = false;
      notifyListeners();
    }
  }

  String _monthKey() {
    return '${_referenceMonth.year}-'
        '${_referenceMonth.month.toString().padLeft(2, '0')}';
  }
}
