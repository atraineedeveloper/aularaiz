/// Function exercised by the person responsible for school leadership.
///
/// Stored as optional school data because not every school (and definitely not
/// every multigrade school) has a teacher with leadership duties.
enum SchoolLeadershipRole {
  /// Director(a).
  principal,

  /// Docente con funciones de dirección.
  teacherWithLeadership,

  /// Encargado(a) de dirección.
  actingPrincipal;

  static SchoolLeadershipRole? tryParse(String? value) {
    if (value == null) return null;
    for (final role in SchoolLeadershipRole.values) {
      if (role.name == value.trim()) return role;
    }
    return null;
  }
}
