import 'package:aularaiz/l10n/generated/app_localizations.dart';

extension EvaluationLocalization on AppLocalizations {
  bool get _evaluationEnglish => localeName.startsWith('en');

  String get evaluationTitle =>
      _evaluationEnglish ? 'Formative evaluation' : 'Evaluación formativa';
  String get openEvaluation => _evaluationEnglish ? 'Evaluation' : 'Evaluación';
  String get evaluationActivity => _evaluationEnglish ? 'Activity' : 'Actividad';
  String get evaluationNoActivities => _evaluationEnglish
      ? 'Create at least one project activity before evaluating students.'
      : 'Crea al menos una actividad de proyecto antes de evaluar a los alumnos.';
  String get evaluationHistoricalRosterHelp => _evaluationEnglish
      ? 'Only the historical roster captured when this activity was created can be evaluated.'
      : 'Solo se puede evaluar al roster histórico que quedó registrado al crear esta actividad.';
  String get evaluationDelivery => _evaluationEnglish ? 'Delivery' : 'Entrega';
  String get evaluationAchievement => _evaluationEnglish ? 'Achievement' : 'Logro';
  String get evaluationObservation =>
      _evaluationEnglish ? 'Observation' : 'Observación';
  String get evaluationPending => _evaluationEnglish ? 'Pending' : 'Pendiente';
  String get evaluationDelivered => _evaluationEnglish ? 'Delivered' : 'Entregó';
  String get evaluationNotDelivered =>
      _evaluationEnglish ? 'Not delivered' : 'No entregó';
  String get evaluationAwaiting =>
      _evaluationEnglish ? 'Awaiting evaluation' : 'Por evaluar';
  String get achievementMastered => _evaluationEnglish ? 'Mastered' : 'Dominado';
  String get achievementSufficient =>
      _evaluationEnglish ? 'Sufficient' : 'Suficiente';
  String get achievementInProgress =>
      _evaluationEnglish ? 'In progress' : 'En proceso';
  String get achievementRequiresSupport =>
      _evaluationEnglish ? 'Requires support' : 'Requiere apoyo';
  String get evaluationEdit => _evaluationEnglish ? 'Evaluate' : 'Evaluar';
  String get evaluationSave => _evaluationEnglish ? 'Save evaluation' : 'Guardar evaluación';
  String get evaluationSaveError => _evaluationEnglish
      ? 'The evaluation could not be saved.'
      : 'No se pudo guardar la evaluación.';
  String get evaluationAll => _evaluationEnglish ? 'All' : 'Todos';
  String get evaluationEvaluated => _evaluationEnglish ? 'Evaluated' : 'Evaluados';
  String get evaluationFilter => _evaluationEnglish ? 'Filter' : 'Filtro';
  String get evaluationStudents => _evaluationEnglish ? 'Students' : 'Alumnos';
  String get evaluationDeliveredMetric =>
      _evaluationEnglish ? 'Delivered' : 'Entregaron';
  String get evaluationPendingMetric => _evaluationEnglish ? 'Pending' : 'Pendientes';
  String get evaluationCompliance =>
      _evaluationEnglish ? 'Delivery compliance' : 'Cumplimiento de entrega';
  String get evaluationNoDecision => _evaluationEnglish
      ? 'No decided deliveries yet'
      : 'Aún no hay entregas decididas';
  String get evaluationNoResults => _evaluationEnglish
      ? 'No students match this filter.'
      : 'No hay alumnos que coincidan con este filtro.';
}
