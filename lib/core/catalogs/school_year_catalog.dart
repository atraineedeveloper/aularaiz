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
  static SchoolYearPreset forStartYear(int year) {
    switch (year) {
      case 2024:
        return SchoolYearPreset(
          label: '2024-2025',
          startsOn: DateTime(2024, 8, 26),
          endsOn: DateTime(2025, 7, 16),
        );
      case 2025:
        return SchoolYearPreset(
          label: '2025-2026',
          startsOn: DateTime(2025, 9, 1),
          endsOn: DateTime(2026, 7, 15),
        );
      case 2026:
        return SchoolYearPreset(
          label: '2026-2027',
          startsOn: DateTime(2026, 8, 31),
          endsOn: DateTime(2027, 7, 9),
        );
      default:
        // Future SEP calendars are not published yet. Keep a broad
        // administrative range until an official calendar can replace it.
        return SchoolYearPreset(
          label: '$year-${year + 1}',
          startsOn: DateTime(year, 8, 1),
          endsOn: DateTime(year + 1, 7, 31),
        );
    }
  }

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
