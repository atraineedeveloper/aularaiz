final class SchoolYearPreset {
  const SchoolYearPreset({
    required this.label,
    required this.startsOn,
    required this.endsOn,
  });

  final String label;
  final DateTime startsOn;
  final DateTime endsOn;
}

abstract final class SchoolYearCatalog {
  static final SchoolYearPreset basicEducation2026_2027 = SchoolYearPreset(
    label: '2026-2027',
    startsOn: DateTime(2026, 8, 31),
    endsOn: DateTime(2027, 7, 9),
  );

  static SchoolYearPreset currentBasicEducation([DateTime? now]) {
    final date = now ?? DateTime.now();
    final preset = basicEducation2026_2027;

    // The 2026-2027 SEP calendar is the currently supported official
    // basic-education cycle. Keeping this explicit prevents guessed dates from
    // silently becoming school records. Add the next official preset only
    // after SEP publishes it.
    if (!date.isBefore(DateTime(2026, 7, 1)) &&
        date.isBefore(DateTime(2027, 8, 1))) {
      return preset;
    }

    return preset;
  }
}
