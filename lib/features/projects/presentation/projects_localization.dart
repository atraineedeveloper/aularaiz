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
  String get formativeField => _english ? 'Formative field' : 'Campo formativo';
  String get activitiesTitle => _english ? 'Activities' : 'Actividades';
  String get activitiesEmpty => _english
      ? 'No activities have been created yet.'
      : 'Aún no se han creado actividades.';
  String get addActivity => _english ? 'Add activity' : 'Agregar actividad';
  String get activityTitle =>
      _english ? 'Activity title' : 'Título de la actividad';
  String get activityGradeScope =>
      _english ? 'Applicable grades' : 'Grados a los que aplica';
  String get activityRosterSnapshotHelp => _english
      ? 'The activity freezes today’s applicable student roster so later enrollment changes do not alter its history.'
      : 'La actividad congela el roster de alumnos aplicable hoy para que cambios posteriores de matrícula no alteren su historial.';
  String get openProjects => _english ? 'Projects' : 'Proyectos';

  String activityRosterCount(int count) => _english
      ? '$count students in historical roster'
      : '$count alumnos en el roster histórico';

  String get methodologyUnspecified =>
      _english ? 'Unspecified' : 'Sin especificar';
  String get methodologyCommunityProjects =>
      _english ? 'Community projects' : 'Proyectos comunitarios';
  String get methodologyInquirySteam =>
      _english ? 'STEAM inquiry' : 'Indagación STEAM';
  String get methodologyProblemBased =>
      _english ? 'Problem-based learning' : 'Aprendizaje basado en problemas';
  String get methodologyServiceLearning =>
      _english ? 'Service learning' : 'Aprendizaje servicio';

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
}
