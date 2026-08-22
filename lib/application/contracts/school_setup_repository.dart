import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_year.dart';

abstract interface class SchoolSetupRepository {
  Future<bool> hasInitialSetup();

  Future<void> saveInitialSetup({
    required School school,
    required SchoolYear schoolYear,
  });
}
