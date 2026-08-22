import 'package:aularaiz/domain/school/school_year.dart';

abstract interface class SchoolYearRepository {
  Future<SchoolYear?> findById(String id);
}
