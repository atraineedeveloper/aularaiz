final class Student {
  Student({
    required this.id,
    required this.givenNames,
    required this.firstSurname,
    this.secondSurname,
    DateTime? birthDate,
  }) : birthDate = birthDate == null
           ? null
           : DateTime(birthDate.year, birthDate.month, birthDate.day) {
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
  final DateTime? birthDate;

  String get displayName {
    final parts = <String>[givenNames.trim(), firstSurname.trim()];
    final second = secondSurname?.trim();
    if (second != null) parts.add(second);
    return parts.join(' ');
  }

  int? ageOn(DateTime referenceDate) {
    final birth = birthDate;
    if (birth == null) return null;

    final reference = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    if (birth.isAfter(reference)) return null;

    var age = reference.year - birth.year;
    final birthdayHasNotOccurred = reference.month < birth.month ||
        (reference.month == birth.month && reference.day < birth.day);
    if (birthdayHasNotOccurred) age--;
    return age;
  }
}
