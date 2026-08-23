import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/evaluation/evaluation_state.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/activity_participant.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:flutter/foundation.dart';

export 'package:aularaiz/features/evaluation/presentation/evaluation_localization.dart';

enum EvaluationFilter {
  all,
  pending,
  awaitingEvaluation,
  notDelivered,
  evaluated,
}

final class EvaluationActivityOption {
  const EvaluationActivityOption({
    required this.project,
    required this.activity,
  });
  final Project project;
  final Activity activity;
}

final class EvaluationStudentRow {
  const EvaluationStudentRow({
    required this.participant,
    required this.student,
    required this.evaluation,
  });
  final ActivityParticipant participant;
  final Student? student;
  final ActivityEvaluation evaluation;
  String get studentId => participant.studentId;
  EvaluationStudentRow withEvaluation(ActivityEvaluation value) =>
      EvaluationStudentRow(
        participant: participant,
        student: student,
        evaluation: value,
      );
}

final class EvaluationMatrixRow {
  const EvaluationMatrixRow({required this.studentId, required this.student});
  final String studentId;
  final Student? student;
}

final class EvaluationMetrics {
  const EvaluationMetrics({
    required this.total,
    required this.pending,
    required this.delivered,
    required this.notDelivered,
    required this.evaluated,
  });
  final int total;
  final int pending;
  final int delivered;
  final int notDelivered;
  final int evaluated;
  int get decidedDeliveries => delivered + notDelivered;
  double? get deliveryCompliance =>
      decidedDeliveries == 0 ? null : delivered / decidedDeliveries;
}

final class EvaluationController extends ChangeNotifier {
  EvaluationController({
    required ProjectRepository projectRepository,
    required ActivityRepository activityRepository,
    required StudentRepository studentRepository,
    required EvaluationRepository evaluationRepository,
    required SaveActivityEvaluation saveActivityEvaluation,
    EnrollmentRepository? enrollmentRepository,
    String? initialActivityId,
  }) : _projectRepository = projectRepository,
       _activityRepository = activityRepository,
       _studentRepository = studentRepository,
       _evaluationRepository = evaluationRepository,
       _saveActivityEvaluation = saveActivityEvaluation,
       _enrollmentRepository = enrollmentRepository,
       _initialActivityId = initialActivityId;

  final ProjectRepository _projectRepository;
  final ActivityRepository _activityRepository;
  final StudentRepository _studentRepository;
  final EvaluationRepository _evaluationRepository;
  final SaveActivityEvaluation _saveActivityEvaluation;
  final EnrollmentRepository? _enrollmentRepository;
  final String? _initialActivityId;

  TeachingGroup? _group;
  List<EvaluationActivityOption> _options = const [];
  EvaluationActivityOption? _selected;
  final Map<String, Map<String, EvaluationStudentRow>> _rowsByActivity = {};
  EvaluationFilter _filter = EvaluationFilter.all;
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  TeachingGroup? get group => _group;
  List<EvaluationActivityOption> get options => _options;
  EvaluationActivityOption? get selected => _selected;
  EvaluationFilter get filter => _filter;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;
  String? get selectedProjectId => _selected?.project.id;

  List<Project> get projects {
    final result = <Project>[];
    final seen = <String>{};
    for (final option in _options) {
      if (seen.add(option.project.id)) result.add(option.project);
    }
    return List<Project>.unmodifiable(result);
  }

  List<EvaluationActivityOption> get projectActivities => List.unmodifiable(
    _options.where((option) => option.project.id == selectedProjectId),
  );

  List<EvaluationStudentRow> get rows {
    final selected = _selected;
    if (selected == null) return const [];
    final values = _rowsByActivity[selected.activity.id]?.values.toList() ?? [];
    values.sort(_compareRows);
    return List.unmodifiable(values);
  }

  List<EvaluationMatrixRow> get matrixRows {
    final ids = <String>{};
    for (final option in projectActivities) {
      ids.addAll(_rowsByActivity[option.activity.id]?.keys ?? const <String>[]);
    }
    final result = <EvaluationMatrixRow>[];
    for (final id in ids) {
      Student? student;
      for (final option in projectActivities) {
        student = _rowsByActivity[option.activity.id]?[id]?.student;
        if (student != null) break;
      }
      result.add(EvaluationMatrixRow(studentId: id, student: student));
    }
    result.sort(
      (a, b) => (a.student?.displayName ?? a.studentId).compareTo(
        b.student?.displayName ?? b.studentId,
      ),
    );
    return List.unmodifiable(result);
  }

  EvaluationStudentRow? cell(String activityId, String studentId) =>
      _rowsByActivity[activityId]?[studentId];

  List<EvaluationStudentRow> get visibleRows => List.unmodifiable(
    rows.where(
      (row) => switch (_filter) {
        EvaluationFilter.all => true,
        EvaluationFilter.pending =>
          row.evaluation.state == EvaluationState.pendingDeliveryDecision,
        EvaluationFilter.awaitingEvaluation =>
          row.evaluation.state == EvaluationState.deliveredAwaitingEvaluation,
        EvaluationFilter.notDelivered =>
          row.evaluation.state == EvaluationState.notDelivered,
        EvaluationFilter.evaluated =>
          row.evaluation.state == EvaluationState.deliveredAndEvaluated,
      },
    ),
  );

  EvaluationMetrics get metrics {
    var pending = 0, delivered = 0, notDelivered = 0, evaluated = 0;
    for (final row in rows) {
      switch (row.evaluation.state) {
        case EvaluationState.pendingDeliveryDecision:
          pending++;
        case EvaluationState.deliveredAwaitingEvaluation:
          delivered++;
        case EvaluationState.notDelivered:
          notDelivered++;
        case EvaluationState.deliveredAndEvaluated:
          delivered++;
          evaluated++;
      }
    }
    return EvaluationMetrics(
      total: rows.length,
      pending: pending,
      delivered: delivered,
      notDelivered: notDelivered,
      evaluated: evaluated,
    );
  }

  Future<void> load(TeachingGroup group) async {
    _group = group;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final projects = await _projectRepository.listForGroup(group.id);
      final options = <EvaluationActivityOption>[];
      for (final project in projects) {
        for (var activity in await _activityRepository.listForProject(
          project.id,
        )) {
          var option = EvaluationActivityOption(
            project: project,
            activity: activity,
          );
          if (activity.roster.isEmpty) {
            option = await _repairEmptyRoster(option);
          }
          options.add(option);
        }
      }
      _options = List.unmodifiable(options);
      _selected = options.isEmpty
          ? null
          : options
                    .where((o) => o.activity.id == _initialActivityId)
                    .firstOrNull ??
                options.first;
      await _loadMatrix();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectActivity(String activityId) async {
    final matches = _options.where((o) => o.activity.id == activityId);
    if (matches.isEmpty) return;
    _selected = matches.first;
    notifyListeners();
  }

  void selectProject(String projectId) {
    final matches = _options.where((o) => o.project.id == projectId);
    if (matches.isEmpty) return;
    _selected = matches.first;
    notifyListeners();
  }

  void setFilter(EvaluationFilter value) {
    _filter = value;
    notifyListeners();
  }

  Future<bool> save({
    required String studentId,
    required DeliveryStatus deliveryStatus,
    AchievementLevel? achievement,
    String? observation,
  }) async {
    final selected = _selected;
    if (selected == null) return false;
    return saveCell(
      activityId: selected.activity.id,
      studentId: studentId,
      deliveryStatus: deliveryStatus,
      achievement: achievement,
      observation: observation,
    );
  }

  Future<bool> saveCell({
    required String activityId,
    required String studentId,
    required DeliveryStatus deliveryStatus,
    AchievementLevel? achievement,
    String? observation,
  }) async {
    if (_isSaving || cell(activityId, studentId) == null) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await _saveActivityEvaluation(
        activityId: activityId,
        studentId: studentId,
        deliveryStatus: deliveryStatus,
        achievement: achievement,
        observation: observation,
      );
      final current = _rowsByActivity[activityId]![studentId]!;
      _rowsByActivity[activityId]![studentId] = current.withEvaluation(saved);
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _loadMatrix() async {
    _rowsByActivity.clear();
    for (final option in _options) {
      final evaluations = await _evaluationRepository.listForActivity(
        option.activity.id,
      );
      final byStudent = {
        for (final value in evaluations) value.studentId: value,
      };
      final rows = <String, EvaluationStudentRow>{};
      for (final participant in option.activity.roster.values) {
        final student = await _studentRepository.findById(
          participant.studentId,
        );
        rows[participant.studentId] = EvaluationStudentRow(
          participant: participant,
          student: student,
          evaluation:
              byStudent[participant.studentId] ??
              ActivityEvaluation(
                activityId: option.activity.id,
                studentId: participant.studentId,
                deliveryStatus: DeliveryStatus.pending,
              ),
        );
      }
      _rowsByActivity[option.activity.id] = rows;
    }
  }

  Future<EvaluationActivityOption> _repairEmptyRoster(
    EvaluationActivityOption option,
  ) async {
    final repository = _enrollmentRepository;
    final group = _group;
    if (repository == null || group == null) return option;
    final eligible = (await repository.findByGroupId(group.id))
        .where((e) => option.activity.targetGrades.contains(e.grade))
        .toList();
    if (eligible.isEmpty) return option;
    final reference = _bestRosterDate(eligible, option.activity.occursOn);
    final participants = <ActivityParticipant>[
      for (final enrollment in eligible)
        if (enrollment.isActiveOn(reference))
          ActivityParticipant(
            studentId: enrollment.studentId,
            grade: enrollment.grade,
          ),
    ];
    if (participants.isEmpty) return option;
    final repaired = Activity(
      id: option.activity.id,
      projectId: option.activity.projectId,
      identifier: option.activity.identifier,
      title: option.activity.title,
      occursOn: option.activity.occursOn,
      formativeField: option.activity.formativeField,
      targetGrades: option.activity.targetGrades,
      roster: participants,
    );
    await _activityRepository.save(repaired);
    return EvaluationActivityOption(
      project: option.project,
      activity: repaired,
    );
  }

  DateTime _bestRosterDate(List<Enrollment> eligible, DateTime? activityDate) {
    final now = activityDate ?? DateTime.now();
    final reference = DateTime(now.year, now.month, now.day);
    if (eligible.any((e) => e.isActiveOn(reference))) return reference;
    final upcoming =
        eligible
            .map((e) => e.startsOn)
            .where((d) => d.isAfter(reference))
            .toList()
          ..sort();
    if (upcoming.isNotEmpty) return upcoming.first;
    final starts = eligible.map((e) => e.startsOn).toList()..sort();
    return starts.last;
  }

  int _compareRows(EvaluationStudentRow a, EvaluationStudentRow b) =>
      (a.student?.displayName ?? a.studentId).compareTo(
        b.student?.displayName ?? b.studentId,
      );
}
