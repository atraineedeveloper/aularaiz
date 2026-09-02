import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_leadership_role.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/school_year.dart';

final class CreateInitialSchoolSetup {
  CreateInitialSchoolSetup({
    required SchoolSetupRepository repository,
    required IdGenerator idGenerator,
  }) : _repository = repository,
       _idGenerator = idGenerator;

  final SchoolSetupRepository _repository;
  final IdGenerator _idGenerator;

  Future<InitialSchoolSetup> call({
    required String schoolName,
    String? cct,
    SchoolOrganization organization = SchoolOrganization.unspecified,
    String? state,
    String? municipality,
    String? locality,
    String? schoolZone,
    String? schoolSector,
    String? supervisorName,
    String? leadershipName,
    SchoolLeadershipRole? leadershipRole,
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final normalizedName = schoolName.trim().toLowerCase();
    final existing = await _repository.listSetups();
    if (existing.any(
      (setup) => setup.school.name.trim().toLowerCase() == normalizedName,
    )) {
      throw StateError('A school with the same name already exists.');
    }

    final normalizedCct = cct?.trim().toUpperCase();
    if (normalizedCct != null &&
        normalizedCct.isNotEmpty &&
        existing.any(
          (setup) => setup.school.cct?.trim().toUpperCase() == normalizedCct,
        )) {
      throw StateError('A school with the same CCT already exists.');
    }

    final school = School(
      id: _idGenerator.newId(),
      name: schoolName,
      cct: cct,
      organization: organization,
      state: state,
      municipality: municipality,
      locality: locality,
      schoolZone: schoolZone,
      schoolSector: schoolSector,
      supervisorName: supervisorName,
      leadershipName: leadershipName,
      leadershipRole: leadershipRole,
    );
    final schoolYear = SchoolYear(
      id: _idGenerator.newId(),
      label: schoolYearLabel,
      startsOn: startsOn,
      endsOn: endsOn,
    );

    await _repository.saveInitialSetup(school: school, schoolYear: schoolYear);
    return (school: school, schoolYear: schoolYear);
  }
}
