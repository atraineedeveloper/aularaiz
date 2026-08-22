import 'package:aularaiz/domain/education/nem_phase.dart';

enum PrimaryGrade {
  first(1, NemPhase.phase3),
  second(2, NemPhase.phase3),
  third(3, NemPhase.phase4),
  fourth(4, NemPhase.phase4),
  fifth(5, NemPhase.phase5),
  sixth(6, NemPhase.phase5);

  const PrimaryGrade(this.number, this.phase);

  final int number;
  final NemPhase phase;

  static PrimaryGrade fromNumber(int number) {
    for (final grade in values) {
      if (grade.number == number) return grade;
    }

    throw ArgumentError.value(
      number,
      'number',
      'Primary grade must be between 1 and 6.',
    );
  }
}
