import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:flutter/foundation.dart';

final class SchoolSetupController extends ChangeNotifier {
  SchoolSetupController(this._createInitialWorkspace);

  final CreateInitialWorkspace _createInitialWorkspace;

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
    String? schoolZone,
    String? schoolSector,
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
    required String groupName,
    required Set<PrimaryGrade> grades,
    String? shift,
    TeachingContract? contract,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _createInitialWorkspace(
        schoolName: schoolName,
        cct: cct,
        organization: organization,
        state: state,
        municipality: municipality,
        locality: locality,
        schoolZone: schoolZone,
        schoolSector: schoolSector,
        schoolYearLabel: schoolYearLabel,
        startsOn: startsOn,
        endsOn: endsOn,
        groupName: groupName,
        grades: grades,
        shift: shift,
        contract: contract,
      );
      SafeLog.operationSuccess('create_initial_workspace');
      return true;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('create_school_setup', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
