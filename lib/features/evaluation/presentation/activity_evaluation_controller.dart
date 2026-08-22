import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/evaluation/save_activity_evaluation.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/activity_evaluation.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:flutter/foundation.dart';

final class ActivityEvaluationEntry {
  ActivityEvaluationEntry({
    required this.student,
    required this.grade,
    required this.deliveryStatus,
    required this.achievement,
    required this.observation,
  });

  final Student student;
  final PrimaryGrade grade;
  DeliveryStatus deliveryStatus;
  AchievementLevel? achievement;
  String observation;
  bool dirty = false;
}

final class ActivityEvaluationController extends ChangeNotifier {
  ActivityEvaluationController({
    required EvaluationRepository evaluationRepository,
    required StudentRepository studentRepository,
    required SaveActivityEvaluation saveActivityEvaluation,
  }) : _evaluationRepository = evaluationRepository,
       _studentRepository = studentRepository,
       _saveActivityEvaluation = saveActivityEvaluation;

  final EvaluationRepository _evaluationRepository;
  final StudentRepository _studentRepository;
  final SaveActivityEvaluation _saveActivityEvaluation;

  Activity? _activity;
  List<ActivityEvaluationEntry> _entries = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  Activity? get activity => _activity;
  List<ActivityEvaluationEntry> get entries => _entries;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;
  bool get hasUnsavedChanges => _entries.any((entry) => entry.dirty);

  int get evaluatedCount => _entries
      .where(
        (entry) =>
            entry.deliveryStatus == DeliveryStatus.delivered &&
            entry.achievement != null,
      )
      .length;

  int get pendingCount => _entries
      .where((entry) => entry.deliveryStatus == DeliveryStatus.pending)
      .length;

  Future<void> load(Activity activity) async {
    _activity = activity;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final existing = await _evaluationRepository.listForActivity(activity.id);
      final byStudent = {
        for (final evaluation in existing) evaluation.studentId: evaluation,
      };
      final participants = activity.roster.values.toList()
        ..sort((left, right) {
          final gradeCompare = left.grade.number.compareTo(right.grade.number);
          return gradeCompare != 0
              ? gradeCompare
              : left.studentId.compareTo(right.studentId);
        });
      final loaded = <ActivityEvaluationEntry>[];
      for (final participant in participants) {
        final student = await _studentRepository.findById(participant.studentId);
        if (student == null) continue;
        final evaluation = byStudent[student.id];
        loaded.add(
          ActivityEvaluationEntry(
            student: student,
            grade: participant.grade,
            deliveryStatus:
                evaluation?.deliveryStatus ?? DeliveryStatus.pending,
            achievement: evaluation?.achievement,
            observation: evaluation?.observation ?? '',
          ),
        );
      }
      loaded.sort((left, right) {
        final gradeCompare = left.grade.number.compareTo(right.grade.number);
        return gradeCompare != 0
            ? gradeCompare
            : left.student.displayName.compareTo(right.student.displayName);
      });
      _entries = List<ActivityEvaluationEntry>.unmodifiable(loaded);
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setDelivery(String studentId, DeliveryStatus status) {
    final entry = _entry(studentId);
    if (entry.deliveryStatus == status) return;
    entry.deliveryStatus = status;
    if (status != DeliveryStatus.delivered) {
      entry.achievement = null;
    }
    entry.dirty = true;
    notifyListeners();
  }

  void setAchievement(String studentId, AchievementLevel? achievement) {
    final entry = _entry(studentId);
    if (entry.deliveryStatus != DeliveryStatus.delivered) return;
    if (entry.achievement == achievement) return;
    entry.achievement = achievement;
    entry.dirty = true;
    notifyListeners();
  }

  void setObservation(String studentId, String observation) {
    final entry = _entry(studentId);
    if (entry.observation == observation) return;
    entry.observation = observation;
    entry.dirty = true;
  }

  void markAllDelivered() {
    var changed = false;
    for (final entry in _entries) {
      if (entry.deliveryStatus == DeliveryStatus.delivered) continue;
      entry.deliveryStatus = DeliveryStatus.delivered;
      entry.dirty = true;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<bool> saveAll() async {
    final activity = _activity;
    if (activity == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      for (final entry in _entries.where((entry) => entry.dirty)) {
        await _saveActivityEvaluation(
          ActivityEvaluation(
            activityId: activity.id,
            studentId: entry.student.id,
            deliveryStatus: entry.deliveryStatus,
            achievement: entry.achievement,
            observation: entry.observation,
          ),
        );
        entry.dirty = false;
      }
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void allowDiscard() {
    for (final entry in _entries) {
      entry.dirty = false;
    }
    notifyListeners();
  }

  ActivityEvaluationEntry _entry(String studentId) {
    return _entries.firstWhere((entry) => entry.student.id == studentId);
  }
}
