import 'package:aularaiz/domain/education/nem_phase.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
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
}
