import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('school preserves structured organization and location context', () {
    final school = School(
      id: 'school-1',
      name: 'Benito Juárez',
      cct: '27DPR0001A',
      organization: SchoolOrganization.twoTeacher,
      state: 'Tabasco',
      municipality: 'Balancán',
      locality: 'San Elpidio',
    );

    expect(school.organization, SchoolOrganization.twoTeacher);
    expect(school.state, 'Tabasco');
    expect(school.municipality, 'Balancán');
    expect(school.locality, 'San Elpidio');
  });

  test('teaching group keeps shift and validated class schedule', () {
    final group = TeachingGroup(
      id: 'group-1',
      schoolId: 'school-1',
      schoolYearId: 'year-1',
      name: '1A',
      grades: <PrimaryGrade>{PrimaryGrade.first},
      shift: 'Matutino',
      schedule: ClassSchedule(startsAtMinutes: 8 * 60, endsAtMinutes: 13 * 60),
    );

    expect(group.shift, 'Matutino');
    expect(group.schedule?.startsAtMinutes, 480);
    expect(group.schedule?.endsAtMinutes, 780);
  });

  test('class schedule rejects invalid or reversed ranges', () {
    expect(
      () => ClassSchedule(startsAtMinutes: -1, endsAtMinutes: 780),
      throwsArgumentError,
    );
    expect(
      () => ClassSchedule(startsAtMinutes: 780, endsAtMinutes: 480),
      throwsArgumentError,
    );
  });
}
