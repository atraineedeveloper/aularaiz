final class Student {
  Student({
    required this.id,
    required this.givenNames,
    required this.firstSurname,
    this.secondSurname,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Student id cannot be empty.');
    }
    if (givenNames.trim().isEmpty) {
      throw ArgumentError.value(
        givenNames,
        'givenNames',
        'Given names cannot be empty.',
      );
    }
    if (firstSurname.trim().isEmpty) {
      throw ArgumentError.value(
        firstSurname,
        'firstSurname',
        'First surname cannot be empty.',
      );
    }
    if (secondSurname != null && secondSurname!.trim().isEmpty) {
      throw ArgumentError.value(
        secondSurname,
        'secondSurname',
        'Second surname cannot be blank when present.',
      );
    }
  }

  final String id;
  final String givenNames;
  final String firstSurname;
  final String? secondSurname;

  String get displayName {
    final parts = <String>[givenNames.trim(), firstSurname.trim()];
    final second = secondSurname?.trim();
    if (second != null) parts.add(second);
    return parts.join(' ');
  }
}
