/// Identity of the teacher who administers AulaRaíz on this installation.
///
/// There is exactly one local teacher profile per installation: it survives
/// creating new schools and changing contracts because it never belongs
/// permanently to a school. Sensitive identifiers (CURP, RFC, phone) are
/// intentionally not collected.
final class TeacherProfile {
  TeacherProfile({required String id, required String fullName})
    : id = id.trim(),
      fullName = fullName.trim() {
    if (this.id.isEmpty) {
      throw ArgumentError.value(
        id,
        'id',
        'Teacher profile id cannot be empty.',
      );
    }
    if (this.fullName.isEmpty) {
      throw ArgumentError.value(
        fullName,
        'fullName',
        'Teacher full name cannot be empty.',
      );
    }
  }

  /// Fixed identifier of the single local profile row.
  static const String localProfileId = 'local-teacher';

  final String id;
  final String fullName;

  /// Local profile shaped from storage, tolerating a missing row.
  static TeacherProfile? fromStorage(String? id, String? fullName) {
    if (id == null || fullName == null) return null;
    final trimmedId = id.trim();
    final trimmedName = fullName.trim();
    if (trimmedId.isEmpty || trimmedName.isEmpty) return null;
    return TeacherProfile(id: trimmedId, fullName: trimmedName);
  }
}
