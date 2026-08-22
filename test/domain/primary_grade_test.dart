import 'package:aularaiz/domain/education/nem_phase.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('primary grades map to the expected NEM phases', () {
    expect(PrimaryGrade.first.phase, NemPhase.phase3);
    expect(PrimaryGrade.second.phase, NemPhase.phase3);
    expect(PrimaryGrade.third.phase, NemPhase.phase4);
    expect(PrimaryGrade.fourth.phase, NemPhase.phase4);
    expect(PrimaryGrade.fifth.phase, NemPhase.phase5);
    expect(PrimaryGrade.sixth.phase, NemPhase.phase5);
  });

  test('primary grade can be reconstructed from its number', () {
    for (final grade in PrimaryGrade.values) {
      expect(PrimaryGrade.fromNumber(grade.number), grade);
    }
  });

  test('invalid primary grade numbers are rejected', () {
    expect(() => PrimaryGrade.fromNumber(0), throwsArgumentError);
    expect(() => PrimaryGrade.fromNumber(7), throwsArgumentError);
  });
}
