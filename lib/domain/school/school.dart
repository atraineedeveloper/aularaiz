import 'package:aularaiz/domain/school/school_leadership_role.dart';
import 'package:aularaiz/domain/school/school_organization.dart';

final class School {
  School({
    required String id,
    required String name,
    String? cct,
    this.organization = SchoolOrganization.unspecified,
    String? state,
    String? municipality,
    String? locality,
    String? schoolZone,
    String? schoolSector,
    String? supervisorName,
    String? leadershipName,
    this.leadershipRole,
  }) : id = id.trim(),
       name = name.trim(),
       cct = _normalizeOptionalText(cct),
       state = _normalizeOptionalText(state),
       municipality = _normalizeOptionalText(municipality),
       locality = _normalizeOptionalText(locality),
       schoolZone = _normalizeOptionalText(schoolZone),
       schoolSector = _normalizeOptionalText(schoolSector),
       supervisorName = _normalizeOptionalText(supervisorName),
       leadershipName = _normalizeOptionalText(leadershipName) {
    if (this.id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'School id cannot be empty.');
    }
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'School name cannot be empty.');
    }
  }

  final String id;
  final String name;
  final String? cct;
  final SchoolOrganization organization;
  final String? state;
  final String? municipality;
  final String? locality;
  final String? schoolZone;
  final String? schoolSector;
  final String? supervisorName;
  final String? leadershipName;
  final SchoolLeadershipRole? leadershipRole;

  static String? _normalizeOptionalText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
