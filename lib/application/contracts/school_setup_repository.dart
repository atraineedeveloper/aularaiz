import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';

typedef InitialSchoolSetup = ({School school, SchoolYear schoolYear});

abstract interface class SchoolSetupRepository {
  Future<bool> hasInitialSetup();

  Future<InitialSchoolSetup?> loadInitialSetup();

  Future<List<InitialSchoolSetup>> listSetups();

  Future<InitialSchoolSetup?> loadForSchool(String schoolId);

  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  });

  Future<void> updateSchool(School school);
}
