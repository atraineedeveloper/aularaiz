import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/school.dart';
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

  Future<void> call({
    required String schoolName,
    String? cct,
    SchoolOrganization organization = SchoolOrganization.unspecified,
    String? state,
    String? municipality,
    String? locality,
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    if (await _repository.hasInitialSetup()) {
      throw StateError('Initial school setup already exists.');
    }

    final school = School(
      id: _idGenerator.newId(),
      name: schoolName,
      cct: cct,
      organization: organization,
      state: state,
      municipality: municipality,
      locality: locality,
    );
    final schoolYear = SchoolYear(
      id: _idGenerator.newId(),
      label: schoolYearLabel,
      startsOn: startsOn,
      endsOn: endsOn,
    );

    await _repository.saveInitialSetup(school: school, schoolYear: schoolYear);
  }
}
