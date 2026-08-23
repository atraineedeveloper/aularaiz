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
  static SchoolYearPreset forStartYear(int year) => SchoolYearPreset(
    label: '$year-${year + 1}',
    startsOn: DateTime(year, 8, 1),
    endsOn: DateTime(year + 1, 7, 31),
  );

  static final List<SchoolYearPreset> basicEducationOptions =
      List<SchoolYearPreset>.unmodifiable([
        for (var year = 2024; year <= 2030; year++) forStartYear(year),
      ]);

  static SchoolYearPreset currentBasicEducation([DateTime? now]) {
    final date = now ?? DateTime.now();
    final startYear = date.month >= 8 ? date.year : date.year - 1;
    final supportedYear = startYear.clamp(2024, 2030);
    return forStartYear(supportedYear);
  }
}
