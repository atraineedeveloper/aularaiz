import 'package:aularaiz/domain/school/school_leadership_role.dart';

/// Function that the local teacher exercises for a school / school-year /
/// teaching-group assignment.
///
/// The role belongs to the assignment (the teaching-group row that also holds
/// the temporary [TeachingContract] dates), not to the teacher profile, so it
/// can change between contracts without duplicating contract data.
enum TeachingRole {
  /// Docente frente a grupo.
  teacher,

  /// Docente con funciones de dirección.
  teacherWithLeadership,

  /// Director(a).
  principal,

  /// Encargado(a) de dirección.
  actingPrincipal;

  /// Whether this role also carries school leadership responsibilities.
  bool get hasLeadership => switch (this) {
        TeachingRole.teacher => false,
        TeachingRole.teacherWithLeadership ||
        TeachingRole.principal ||
        TeachingRole.actingPrincipal => true,
      };

  /// School leadership role that matches this teaching role, when any.
  SchoolLeadershipRole? get leadershipRole => switch (this) {
        TeachingRole.teacher => null,
        TeachingRole.teacherWithLeadership => SchoolLeadershipRole
              .teacherWithLeadership,
        TeachingRole.principal => SchoolLeadershipRole.principal,
        TeachingRole.actingPrincipal => SchoolLeadershipRole.actingPrincipal,
      };

  static TeachingRole? tryParse(String? value) {
    if (value == null) return null;
    for (final role in TeachingRole.values) {
      if (role.name == value.trim()) return role;
    }
    return null;
  }
}
