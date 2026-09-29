import 'package:aularaiz/domain/incident/incident_category.dart';
import 'package:aularaiz/domain/incident/incident_status.dart';
import 'package:flutter/widgets.dart';

String incidentCategoryLabel(BuildContext context, IncidentCategory category) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  return switch (category) {
    IncidentCategory.health => english ? 'Health concern' : 'Salud / malestar',
    IncidentCategory.accident =>
      english ? 'Accident / injury' : 'Accidente / lesión',
    IncidentCategory.coexistence =>
      english ? 'Conflict / coexistence' : 'Conflicto / convivencia',
    IncidentCategory.behavior => english ? 'Behavior' : 'Conducta',
    IncidentCategory.property =>
      english ? 'Property / safety' : 'Daño / seguridad',
    IncidentCategory.other => english ? 'Other' : 'Otra',
  };
}

String incidentStatusLabel(BuildContext context, IncidentStatus status) {
  final english = Localizations.localeOf(context).languageCode == 'en';
  return switch (status) {
    IncidentStatus.open => english ? 'Open' : 'Abierta',
    IncidentStatus.followUp => english ? 'Follow-up' : 'Seguimiento',
    IncidentStatus.closed => english ? 'Closed' : 'Cerrada',
  };
}
