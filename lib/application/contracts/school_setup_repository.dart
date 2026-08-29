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
}

abstract interface class EditableSchoolSetupRepository {
  Future<void> updateSchool(School school);
}

abstract interface class DeletableSchoolSetupRepository {
  Future<void> deleteSchool(String schoolId);
}

abstract interface class SchoolYearStarterRepository {
  Future<void> startSchoolYear({
    required String schoolId,
    required SchoolYear schoolYear,
  });
}

extension SchoolSetupRepositoryEditing on SchoolSetupRepository {
  Future<void> updateSchool(School school) {
    final repository = this;
    if (repository is EditableSchoolSetupRepository) {
      return (repository as EditableSchoolSetupRepository).updateSchool(school);
    }
    throw UnsupportedError('This school repository does not support editing.');
  }
}

extension SchoolSetupRepositoryDeletion on SchoolSetupRepository {
  Future<void> deleteSchool(String schoolId) {
    final repository = this;
    if (repository is DeletableSchoolSetupRepository) {
      return (repository as DeletableSchoolSetupRepository).deleteSchool(
        schoolId,
      );
    }
    throw UnsupportedError('This school repository does not support deletion.');
  }
}
