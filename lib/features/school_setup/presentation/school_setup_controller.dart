import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:flutter/foundation.dart';

final class SchoolSetupController extends ChangeNotifier {
  SchoolSetupController(this._createInitialSchoolSetup);

  final CreateInitialSchoolSetup _createInitialSchoolSetup;

  bool _isSaving = false;
  Object? _error;

  bool get isSaving => _isSaving;
  Object? get error => _error;

  Future<bool> save({
    required String schoolName,
    String? cct,
    required SchoolOrganization organization,
    String? state,
    String? municipality,
    String? locality,
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _createInitialSchoolSetup(
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
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
