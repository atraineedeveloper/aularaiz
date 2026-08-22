import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';

extension EvaluationLocalization on AppLocalizations {
  bool get _evaluationEnglish => localeName.startsWith('en');

  String get formativeEvaluation =>
      _evaluationEnglish ? 'Formative evaluation' : 'Evaluación formativa';
  String get saveEvaluations =>
      _evaluationEnglish ? 'Save evaluations' : 'Guardar evaluaciones';
  String get markAllDelivered =>
      _evaluationEnglish ? 'Mark all delivered' : 'Marcar todos entregados';
  String get evaluationLoadError => _evaluationEnglish
      ? 'The activity evaluation could not be loaded.'
      : 'No se pudo cargar la evaluación de la actividad.';
  String get evaluationSaveError => _evaluationEnglish
      ? 'The evaluations could not be saved.'
      : 'No se pudieron guardar las evaluaciones.';
  String get noEvaluationRoster => _evaluationEnglish
      ? 'This activity has no students in its historical roster.'
      : 'Esta actividad no tiene alumnos en su roster histórico.';
  String get delivery => _evaluationEnglish ? 'Delivery' : 'Entrega';
  String get achievement => _evaluationEnglish ? 'Achievement' : 'Logro';
  String get observation =>
      _evaluationEnglish ? 'Observation' : 'Observación';
  String get noAchievementYet =>
      _evaluationEnglish ? 'Not evaluated yet' : 'Aún sin evaluar';
  String get evaluationShortcut =>
      _evaluationEnglish ? 'Save: Ctrl+S' : 'Guardar: Ctrl+S';
  String get evidenceSummary =>
      _evaluationEnglish ? 'Evidence summary' : 'Resumen de evidencias';
  String get evaluatedCount => _evaluationEnglish ? 'Evaluated' : 'Evaluados';
  String get pendingCount => _evaluationEnglish ? 'Pending' : 'Pendientes';

  String deliveryStatusLabel(DeliveryStatus status) => switch (status) {
    DeliveryStatus.pending => _evaluationEnglish ? 'Pending' : 'Pendiente',
    DeliveryStatus.delivered => _evaluationEnglish ? 'Delivered' : 'Entregado',
    DeliveryStatus.notDelivered =>
      _evaluationEnglish ? 'Not delivered' : 'No entregado',
  };

  String achievementLabel(AchievementLevel level) => switch (level) {
    AchievementLevel.mastered => _evaluationEnglish ? 'Mastered' : 'Domina',
    AchievementLevel.sufficient =>
      _evaluationEnglish ? 'Sufficient' : 'Suficiente',
    AchievementLevel.inProgress =>
      _evaluationEnglish ? 'In progress' : 'En proceso',
    AchievementLevel.requiresSupport => _evaluationEnglish
        ? 'Requires support'
        : 'Requiere apoyo',
  };
}
