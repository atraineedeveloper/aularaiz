import 'package:aularaiz/application/reports/report_models.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/reports/presentation/reports_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({required this.group, super.key});

  final TeachingGroup group;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ReportsController>().load(widget.group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<ReportsController>();
    final report = controller.groupReport;

    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.reportsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              _PrivacyBoundaryNotice(message: l10n.reportsExternalCopyWarning),
              const SizedBox(height: 16),
              _MonthSelector(
                month: controller.referenceMonth,
                onPrevious: controller.isLoading || controller.isPublishing
                    ? null
                    : controller.previousMonth,
                onNext: controller.isLoading || controller.isPublishing
                    ? null
                    : controller.nextMonth,
              ),
              const SizedBox(height: 12),
              _SensitiveSwitch(
                value: controller.includeSensitiveFollowUp,
                enabled: !controller.isPublishing,
                onChanged: _changeSensitive,
              ),
              if (controller.isPublishing) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (controller.error != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.reportsError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : report == null
                    ? Center(child: Text(l10n.reportsError))
                    : report.students.isEmpty
                    ? Center(
                        child: Text(
                          l10n.reportsNoStudents,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 980) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 340,
                                  child: _GroupReportCard(
                                    studentCount: report.students.length,
                                    onGenerate: controller.isPublishing
                                        ? null
                                        : _publishGroup,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: _StudentReportsList(
                                    students: report.students,
                                    enabled: !controller.isPublishing,
                                    onGenerate: _publishIndividual,
                                  ),
                                ),
                              ],
                            );
                          }
                          return ListView(
                            children: [
                              _GroupReportCard(
                                studentCount: report.students.length,
                                onGenerate: controller.isPublishing
                                    ? null
                                    : _publishGroup,
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 520,
                                child: _StudentReportsList(
                                  students: report.students,
                                  enabled: !controller.isPublishing,
                                  onGenerate: _publishIndividual,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeSensitive(bool value) async {
    final controller = context.read<ReportsController>();
    if (!value) {
      controller.setSensitiveFollowUp(false);
      return;
    }

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.reportsSensitiveConfirmTitle),
        content: Text(l10n.reportsSensitiveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.reportsKeepExcluded),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.reportsInclude),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      controller.setSensitiveFollowUp(true);
    }
  }

  Future<void> _publishGroup() async {
    final controller = context.read<ReportsController>();
    final l10n = AppLocalizations.of(context);
    final result = await controller.publishGroup(
      english: l10n.localeName.startsWith('en'),
    );
    if (!mounted) return;
    _showResult(result);
  }

  Future<void> _publishIndividual(String studentId) async {
    final controller = context.read<ReportsController>();
    final l10n = AppLocalizations.of(context);
    final result = await controller.publishIndividual(
      studentId: studentId,
      english: l10n.localeName.startsWith('en'),
    );
    if (!mounted) return;
    _showResult(result);
  }

  void _showResult(ReportPublishResult result) {
    final l10n = AppLocalizations.of(context);
    final message = switch (result) {
      ReportPublishResult.published => l10n.reportsPublished,
      ReportPublishResult.cancelled => l10n.reportsCancelled,
      ReportPublishResult.failed => l10n.reportsError,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PrivacyBoundaryNotice extends StatelessWidget {
  const _PrivacyBoundaryNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: l10n.reportsPreviousMonth,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                l10n.reportsMonth,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(
                MaterialLocalizations.of(context).formatMonthYear(month),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.reportsNextMonth,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _SensitiveSwitch extends StatelessWidget {
  const _SensitiveSwitch({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: enabled ? onChanged : null,
      title: Text(l10n.reportsSensitiveTitle),
      subtitle: Text(l10n.reportsSensitiveDescription),
      secondary: const Icon(Icons.shield_outlined),
    );
  }
}

class _GroupReportCard extends StatelessWidget {
  const _GroupReportCard({required this.studentCount, required this.onGenerate});

  final int studentCount;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.summarize_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              l10n.reportsGroupTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(l10n.reportsGroupDescription),
            const SizedBox(height: 12),
            Text('$studentCount ${l10n.evaluationStudents.toLowerCase()}'),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(l10n.reportsGeneratePdf),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentReportsList extends StatelessWidget {
  const _StudentReportsList({
    required this.students,
    required this.enabled,
    required this.onGenerate,
  });

  final List<StudentReportRow> students;
  final bool enabled;
  final ValueChanged<String> onGenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.reportsIndividualTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(l10n.reportsIndividualDescription),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: students.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = students[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${student.listNumber}')),
                  title: Text(student.displayName),
                  subtitle: Text(
                    '${student.grade.number}° · '
                    '${l10n.reportsAttendance}: ${student.attendance.totalMarked} · '
                    '${l10n.reportsEvaluated}: ${student.evaluation.evaluated}',
                  ),
                  trailing: IconButton(
                    tooltip: l10n.reportsGeneratePdf,
                    onPressed: enabled
                        ? () => onGenerate(student.studentId)
                        : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
