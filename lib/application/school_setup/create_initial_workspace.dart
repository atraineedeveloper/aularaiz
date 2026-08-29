import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';

final class CreateInitialWorkspace {
  CreateInitialWorkspace({
    required CreateInitialSchoolSetup createSchoolSetup,
    required CreateTeachingGroup createTeachingGroup,
    required SchoolSetupRepository schoolSetupRepository,
  }) : _createSchoolSetup = createSchoolSetup,
       _createTeachingGroup = createTeachingGroup,
       _schoolSetupRepository = schoolSetupRepository;

  final CreateInitialSchoolSetup _createSchoolSetup;
  final CreateTeachingGroup _createTeachingGroup;
  final SchoolSetupRepository _schoolSetupRepository;

  Future<void> call({
    required String schoolName,
    String? cct,
    required SchoolOrganization organization,
    String? state,
    String? municipality,
    String? locality,
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
    required String groupName,
    required Set<PrimaryGrade> grades,
    String? shift,
    ClassSchedule? schedule,
    TeachingContract? contract,
  }) async {
    final setup = await _createSchoolSetup(
      schoolName: schoolName,
      cct: cct,
      organization: organization,
      state: state,
      municipality: municipality,
      locality: locality,
      schoolYearLabel: schoolYearLabel,
      startsOn: startsOn,
      endsOn: endsOn,
    );

    try {
      await _createTeachingGroup(
        schoolId: setup.school.id,
        schoolYearId: setup.schoolYear.id,
        name: groupName,
        grades: grades,
        shift: shift,
        schedule: schedule,
        contract: contract,
      );
    } catch (_) {
      await _schoolSetupRepository.deleteSchool(setup.school.id);
      rethrow;
    }
  }
}
