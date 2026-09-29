import 'package:aularaiz/domain/incident/incident_category.dart';
import 'package:aularaiz/domain/incident/incident_status.dart';

final class IncidentReport {
  IncidentReport({
    required this.id,
    required this.schoolId,
    required DateTime occurredAt,
    required this.category,
    required String description,
    required Iterable<String> studentIds,
    this.groupId,
    String? actionTaken,
    String? followUpNote,
    this.familyNotified = false,
    this.leadershipNotified = false,
    this.status = IncidentStatus.open,
    this.correctedAt,
  }) : occurredAt = occurredAt.toUtc(),
       description = description.trim(),
       studentIds = List<String>.unmodifiable(
         studentIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet(),
       ),
       actionTaken = _optional(actionTaken),
       followUpNote = _optional(followUpNote) {
    if (id.trim().isEmpty || schoolId.trim().isEmpty) {
      throw ArgumentError('Incident and school identifiers are required.');
    }
    if (this.description.isEmpty) {
      throw ArgumentError.value(description, 'description', 'Required.');
    }
    if (this.description.length > 1200) {
      throw ArgumentError.value(description, 'description', 'Too long.');
    }
    if ((this.actionTaken?.length ?? 0) > 800 ||
        (this.followUpNote?.length ?? 0) > 800) {
      throw ArgumentError('Incident notes cannot exceed 800 characters.');
    }
  }

  final String id;
  final String schoolId;
  final String? groupId;
  final DateTime occurredAt;
  final IncidentCategory category;
  final String description;
  final String? actionTaken;
  final String? followUpNote;
  final bool familyNotified;
  final bool leadershipNotified;
  final IncidentStatus status;
  final List<String> studentIds;
  final DateTime? correctedAt;

  bool get wasCorrected => correctedAt != null;

  static String? _optional(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
