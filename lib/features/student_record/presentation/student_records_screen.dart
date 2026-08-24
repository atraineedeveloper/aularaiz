import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/student_record_repository.dart';
import 'package:aularaiz/application/student_record/add_student_record_entry.dart';
import 'package:aularaiz/application/student_record/update_student_record.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/features/student_record/presentation/student_record_controller.dart';
import 'package:aularaiz/features/student_record/presentation/student_record_screen.dart';
import 'package:aularaiz/features/student_record/presentation/student_records_controller.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudentRecordsScreen extends StatefulWidget {
  const StudentRecordsScreen({
    required this.group,
    this.embedded = false,
    this.onOpenRecord,
    super.key,
  });

  final TeachingGroup group;
  final bool embedded;
  final ValueChanged<StudentRecordRosterEntry>? onOpenRecord;

  @override
  State<StudentRecordsScreen> createState() => _StudentRecordsScreenState();
}

class _StudentRecordsScreenState extends State<StudentRecordsScreen> {
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StudentRecordsController>().load(widget.group);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = context.watch<StudentRecordsController>();

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(widget.group.name)),
      body: SafeArea(
        top: !widget.embedded,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.studentRecordsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              if (controller.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.studentRecordLoadingError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              Expanded(
                child: controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : controller.entries.isEmpty
                    ? Center(
                        child: Text(
                          l10n.studentRecordsEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1000 ? 2 : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 12) /
                              columns;
                          return SingleChildScrollView(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (final entry in controller.entries)
                                  SizedBox(
                                    width: width,
                                    child: Card(
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          child: Text(
                                            '${entry.enrollment.listNumber}',
                                          ),
                                        ),
                                        title: Text(entry.student.displayName),
                                        subtitle: Text(
                                          '${entry.enrollment.grade.number}° · '
                                          '${entry.isActive ? l10n.studentRecordActive : l10n.studentRecordHistorical}',
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                        onTap: () => _openRecord(entry),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
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

  Future<void> _openRecord(StudentRecordRosterEntry entry) async {
    final onOpenRecord = widget.onOpenRecord;
    if (onOpenRecord != null) {
      onOpenRecord(entry);
      return;
    }
    final studentRecordRepository = context.read<StudentRecordRepository>();
    final attendanceRepository = context.read<AttendanceRepository>();
    final evaluationRepository = context.read<EvaluationRepository>();
    final activityRepository = context.read<ActivityRepository>();
    final updateStudentRecord = context.read<UpdateStudentRecord>();
    final addStudentRecordEntry = context.read<AddStudentRecordEntry>();

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => StudentRecordController(
            studentRecordRepository: studentRecordRepository,
            attendanceRepository: attendanceRepository,
            evaluationRepository: evaluationRepository,
            activityRepository: activityRepository,
            updateStudentRecord: updateStudentRecord,
            addStudentRecordEntry: addStudentRecordEntry,
          ),
          child: StudentRecordScreen(
            group: widget.group,
            student: entry.student,
          ),
        ),
      ),
    );
  }
}
