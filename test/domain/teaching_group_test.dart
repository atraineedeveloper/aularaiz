import 'package:aularaiz/domain/education/nem_phase.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group must contain at least one grade', () {
    expect(
      () => TeachingGroup(
        id: 'group-1',
        schoolId: 'school-1',
        schoolYearId: 'year-1',
        name: 'A',
        grades: <PrimaryGrade>{},
      ),
      throwsArgumentError,
    );
  });

  test('multigrade groups expose all represented NEM phases', () {
    final group = TeachingGroup(
      id: 'group-1',
      schoolId: 'school-1',
      schoolYearId: 'year-1',
      name: 'Multigrado',
      grades: <PrimaryGrade>{PrimaryGrade.second, PrimaryGrade.third},
    );

    expect(group.isMultigrade, isTrue);
    expect(group.phases, <NemPhase>{NemPhase.phase3, NemPhase.phase4});
  });

  test('contract is optional and validates its date boundaries', () {
    expect(
      () => TeachingGroup(
        id: 'group-1',
        schoolId: 'school-1',
        schoolYearId: 'year-1',
        name: 'A',
        grades: <PrimaryGrade>{PrimaryGrade.first},
        contract: TeachingContract(
          startsOn: DateTime(2026, 12, 16),
          endsOn: DateTime(2026, 10, 30),
        ),
      ),
      throwsArgumentError,
    );
  });

  test('contract covers dates between its boundaries', () {
    final contract = TeachingContract(
      startsOn: DateTime(2026, 8, 31),
      endsOn: DateTime(2026, 12, 15),
    );
    final group = TeachingGroup(
      id: 'group-1',
      schoolId: 'school-1',
      schoolYearId: 'year-1',
      name: 'A',
      grades: <PrimaryGrade>{PrimaryGrade.first},
      contract: contract,
    );

    expect(group.contract, same(contract));
    expect(contract.contains(DateTime(2026, 9)), isTrue);
    expect(contract.contains(DateTime(2027, 1)), isFalse);
  });
}
