import 'package:aularaiz/l10n/generated/app_localizations.dart';

extension ProjectsLocalization on AppLocalizations {
  bool get _english => localeName.startsWith('en');

  String get projectsTitle => _english ? 'Projects' : 'Proyectos';
  String get projectsEmpty => _english
      ? 'There are no projects for this group yet.'
      : 'Aún no hay proyectos en este grupo.';
  String get createProject => _english ? 'Create project' : 'Crear proyecto';
  String get projectTitle => _english ? 'Project title' : 'Título del proyecto';
  String get projectSaveError => _english
      ? 'The project or activity could not be saved.'
      : 'No se pudo guardar el proyecto o la actividad.';
  String get projectDraft => _english ? 'Draft' : 'Borrador';
  String get projectInProgress => _english ? 'In progress' : 'En curso';
  String get projectCompleted => _english ? 'Completed' : 'Completado';
  String get methodology => _english ? 'Methodology' : 'Metodología';
  String get formativeFields =>
      _english ? 'Formative fields' : 'Campos formativos';
  String get selectAtLeastOneField => _english
      ? 'Select at least one formative field'
      : 'Selecciona al menos un campo formativo';
  String get articulatingAxes =>
      _english ? 'Articulating axes' : 'Ejes articuladores';
  String get articulatingAxesHelp => _english
      ? 'Choose the axes that intentionally cross the project.'
      : 'Selecciona los ejes que atraviesan intencionalmente el proyecto.';
  String get activitiesTitle => _english ? 'Activities' : 'Actividades';
  String get activitiesEmpty => _english
      ? 'No activities have been created yet.'
      : 'Aún no se han creado actividades.';
  String get addActivity => _english ? 'Add activity' : 'Agregar actividad';
  String get activityTitle =>
      _english ? 'Activity title' : 'Título de la actividad';
  String get activityFormativeField =>
      _english ? 'Activity formative field' : 'Campo formativo de la actividad';
  String get activityGradeScope =>
      _english ? 'Applicable grades' : 'Grados a los que aplica';
  String get activityRosterSnapshotHelp => _english
      ? 'The activity freezes today’s applicable student roster so later enrollment changes do not alter its history.'
      : 'La actividad congela el roster de alumnos aplicable hoy para que cambios posteriores de matrícula no alteren su historial.';
  String get openProjects => _english ? 'Projects' : 'Proyectos';
  String get evaluateActivity =>
      _english ? 'Evaluate activity' : 'Evaluar actividad';

  String activityRosterCount(int count) => _english
      ? '$count students in historical roster'
      : '$count alumnos en el roster histórico';

  String get methodologyUnspecified =>
      _english ? 'Unspecified' : 'Sin especificar';
  String get methodologyCommunityProjects => _english
      ? 'Community-Based Project Learning'
      : 'Aprendizaje Basado en Proyectos Comunitarios';
  String get methodologyInquirySteam => _english
      ? 'Inquiry-Based Learning with a STEAM approach'
      : 'Aprendizaje Basado en Indagación con enfoque STEAM';
  String get methodologyProblemBased => _english
      ? 'Problem-Based Learning (PBL)'
      : 'Aprendizaje Basado en Problemas (ABP)';
  String get methodologyServiceLearning => _english
      ? 'Service Learning'
      : 'Aprendizaje Servicio (AS)';

  String get formativeFieldUnspecified =>
      _english ? 'Unspecified' : 'Sin especificar';
  String get formativeFieldLanguages => _english ? 'Languages' : 'Lenguajes';
  String get formativeFieldScientificThought => _english
      ? 'Knowledge and scientific thought'
      : 'Saberes y pensamiento científico';
  String get formativeFieldEthicsNature => _english
      ? 'Ethics, nature and societies'
      : 'Ética, naturaleza y sociedades';
  String get formativeFieldHumanCommunity =>
      _english ? 'Human and community' : 'De lo humano y lo comunitario';

  String get axisInclusion => _english ? 'Inclusion' : 'Inclusión';
  String get axisCriticalThinking =>
      _english ? 'Critical thinking' : 'Pensamiento crítico';
  String get axisCriticalInterculturality => _english
      ? 'Critical interculturality'
      : 'Interculturalidad crítica';
  String get axisGenderEquality =>
      _english ? 'Gender equality' : 'Igualdad de género';
  String get axisHealthyLife =>
      _english ? 'Healthy life' : 'Vida saludable';
  String get axisCulturesReadingWriting => _english
      ? 'Cultures through reading and writing'
      : 'Apropiación de las culturas a través de la lectura y la escritura';
  String get axisArtsAesthetic => _english
      ? 'Arts and aesthetic experiences'
      : 'Artes y experiencias estéticas';
}
