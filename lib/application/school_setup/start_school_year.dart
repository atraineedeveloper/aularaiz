import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/school/school_year.dart';

final class StartSchoolYear {
  StartSchoolYear({
    required SchoolSetupRepository setupRepository,
    required SchoolYearStarterRepository starterRepository,
    required IdGenerator idGenerator,
  }) : _setupRepository = setupRepository,
       _starterRepository = starterRepository,
       _idGenerator = idGenerator;

  final SchoolSetupRepository _setupRepository;
  final SchoolYearStarterRepository _starterRepository;
  final IdGenerator _idGenerator;

  Future<SchoolYear> call({
    required String schoolId,
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final setup = await _setupRepository.loadForSchool(schoolId);
    if (setup == null) {
      throw StateError('Selected school setup is missing.');
    }

    final current = setup.schoolYear;
    if (schoolYearLabel.trim() == current.label ||
        !startsOn.isAfter(current.startsOn)) {
      throw StateError('The new school year must start after the current one.');
    }

    final schoolYear = SchoolYear(
      id: _idGenerator.newId(),
      label: schoolYearLabel,
      startsOn: startsOn,
      endsOn: endsOn,
    );

    await _starterRepository.startSchoolYear(
      schoolId: schoolId,
      schoolYear: schoolYear,
    );
    return schoolYear;
  }
}
