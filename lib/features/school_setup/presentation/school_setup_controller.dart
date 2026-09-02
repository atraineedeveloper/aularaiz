import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/application/teacher/save_teacher_profile.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_leadership_role.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:aularaiz/domain/teacher/teaching_role.dart';
import 'package:flutter/foundation.dart';

final class SchoolSetupController extends ChangeNotifier {
  SchoolSetupController(
    this._createInitialWorkspace, {
    SaveTeacherProfile? saveTeacherProfile,
  }) : _saveTeacherProfile = saveTeacherProfile;

  final CreateInitialWorkspace _createInitialWorkspace;
  final SaveTeacherProfile? _saveTeacherProfile;

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
    String? supervisorName,
    String? leadershipName,
    SchoolLeadershipRole? leadershipRole,
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
    required String groupName,
    required Set<PrimaryGrade> grades,
    String? shift,
    TeachingContract? contract,
    TeachingRole? teachingRole,
    String? teacherName,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      // The teacher profile is saved first so it survives even if the new
      // school or group creation fails: the teacher never loses their local
      // identity when a contract change goes wrong.
      final trimmedTeacherName = teacherName?.trim();
      final saveProfile = _saveTeacherProfile;
      if (saveProfile != null && trimmedTeacherName?.isNotEmpty == true) {
        await saveProfile(fullName: trimmedTeacherName!);
      }
      await _createInitialWorkspace(
        schoolName: schoolName,
        cct: cct,
        organization: organization,
        state: state,
        municipality: municipality,
        locality: locality,
        schoolZone: schoolZone,
        schoolSector: schoolSector,
        supervisorName: supervisorName,
        leadershipName: leadershipName,
        leadershipRole: leadershipRole,
        schoolYearLabel: schoolYearLabel,
        startsOn: startsOn,
        endsOn: endsOn,
        groupName: groupName,
        grades: grades,
        shift: shift,
        contract: contract,
        teachingRole: teachingRole,
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
