abstract final class SchoolShiftCatalog {
  static const unspecified = '';
  static const morning = 'Matutino';
  static const afternoon = 'Vespertino';
  static const night = 'Nocturno';
  static const discontinuous = 'Discontinuo';
  static const continuous = 'Continuo';

  static const officialValues = <String>[
    morning,
    afternoon,
    night,
    discontinuous,
    continuous,
  ];

  static bool isOfficial(String? value) =>
      value != null && officialValues.contains(value.trim());

  static String normalizeForSelection(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return unspecified;
    for (final official in officialValues) {
      if (official.toLowerCase() == normalized.toLowerCase()) return official;
    }
    return normalized;
  }

  static String? persistenceValue(String selection) {
    final normalized = selection.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
