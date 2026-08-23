import 'package:aularaiz/application/contracts/activity_repository.dart';
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

  EvaluationStudentRow withEvaluation(ActivityEvaluation value) {
    return EvaluationStudentRow(
      participant: participant,
      student: student,
      evaluation: value,
    );
  }
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
  }) : _projectRepository = projectRepository,
       _activityRepository = activityRepository,
       _studentRepository = studentRepository,
       _evaluationRepository = evaluationRepository,
       _saveActivityEvaluation = saveActivityEvaluation;

  final ProjectRepository _projectRepository;
  final ActivityRepository _activityRepository;
  final StudentRepository _studentRepository;
  final EvaluationRepository _evaluationRepository;
  final SaveActivityEvaluation _saveActivityEvaluation;

  TeachingGroup? _group;
  List<EvaluationActivityOption> _options = const [];
  EvaluationActivityOption? _selected;
  List<EvaluationStudentRow> _rows = const [];
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

  List<EvaluationStudentRow> get rows => _rows;

  List<EvaluationStudentRow> get visibleRows {
    return List<EvaluationStudentRow>.unmodifiable(
      _rows.where((row) {
        return switch (_filter) {
          EvaluationFilter.all => true,
          EvaluationFilter.pending =>
            row.evaluation.state == EvaluationState.pendingDeliveryDecision,
          EvaluationFilter.awaitingEvaluation =>
            row.evaluation.state == EvaluationState.deliveredAwaitingEvaluation,
          EvaluationFilter.notDelivered =>
            row.evaluation.state == EvaluationState.notDelivered,
          EvaluationFilter.evaluated =>
            row.evaluation.state == EvaluationState.deliveredAndEvaluated,
        };
      }),
    );
  }

  EvaluationMetrics get metrics {
    var pending = 0;
    var delivered = 0;
    var notDelivered = 0;
    var evaluated = 0;
    for (final row in _rows) {
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
      total: _rows.length,
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
        final activities = await _activityRepository.listForProject(project.id);
        for (final activity in activities) {
          options.add(
            EvaluationActivityOption(project: project, activity: activity),
          );
        }
      }
      _options = List<EvaluationActivityOption>.unmodifiable(options);
      _selected = options.isEmpty ? null : options.first;
      await _loadSelectedRows();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectActivity(String activityId) async {
    final next = _options.where((option) => option.activity.id == activityId);
    if (next.isEmpty || _selected?.activity.id == activityId) return;
    _selected = next.first;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _loadSelectedRows();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(EvaluationFilter value) {
    if (_filter == value) return;
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
    if (selected == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final saved = await _saveActivityEvaluation(
        activityId: selected.activity.id,
        studentId: studentId,
        deliveryStatus: deliveryStatus,
        achievement: achievement,
        observation: observation,
      );
      _rows = List<EvaluationStudentRow>.unmodifiable([
        for (final row in _rows)
          row.studentId == studentId ? row.withEvaluation(saved) : row,
      ]);
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _loadSelectedRows() async {
    final selected = _selected;
    if (selected == null) {
      _rows = const [];
      return;
    }

    final evaluations = await _evaluationRepository.listForActivity(
      selected.activity.id,
    );
    final byStudent = {
      for (final evaluation in evaluations) evaluation.studentId: evaluation,
    };
    final participants = selected.activity.roster.values.toList()
      ..sort((left, right) => left.studentId.compareTo(right.studentId));
    final result = <EvaluationStudentRow>[];
    for (final participant in participants) {
      final student = await _studentRepository.findById(participant.studentId);
      result.add(
        EvaluationStudentRow(
          participant: participant,
          student: student,
          evaluation:
              byStudent[participant.studentId] ??
              ActivityEvaluation(
                activityId: selected.activity.id,
                studentId: participant.studentId,
                deliveryStatus: DeliveryStatus.pending,
              ),
        ),
      );
    }
    result.sort((left, right) {
      final leftName = left.student?.displayName ?? left.studentId;
      final rightName = right.student?.displayName ?? right.studentId;
      return leftName.compareTo(rightName);
    });
    _rows = List<EvaluationStudentRow>.unmodifiable(result);
  }
}
