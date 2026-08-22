import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/school/school_year.dart';

final class DriftSchoolYearRepository implements SchoolYearRepository {
  DriftSchoolYearRepository(this.database);

  final AppDatabase database;

  @override
  Future<SchoolYear?> findById(String id) async {
    final row = await (database.select(
      database.schoolYears,
    )..where((table) => table.id.equals(id))).getSingleOrNull();

    if (row == null) return null;

    return SchoolYear(
      id: row.id,
      label: row.label,
      startsOn: row.startsOn,
      endsOn: row.endsOn,
    );
  }
}
