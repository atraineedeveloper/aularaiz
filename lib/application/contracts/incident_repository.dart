import 'package:aularaiz/domain/incident/incident_report.dart';

abstract interface class IncidentRepository {
  Future<List<IncidentReport>> listForSchool(String schoolId);

  Future<List<IncidentReport>> listForStudent(String studentId);

  Future<void> save(IncidentReport report);
}
