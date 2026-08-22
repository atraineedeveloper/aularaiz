final class School {
  School({required this.id, required this.name, this.cct}) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'School id cannot be empty.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'School name cannot be empty.');
    }
    if (cct != null && cct!.trim().isEmpty) {
      throw ArgumentError.value(
        cct,
        'cct',
        'CCT cannot be blank when present.',
      );
    }
  }

  final String id;
  final String name;
  final String? cct;
}
