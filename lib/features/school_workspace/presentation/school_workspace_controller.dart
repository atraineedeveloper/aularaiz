import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/start_school_year.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/teaching_contract.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter/foundation.dart';

final class SchoolWorkspaceController extends ChangeNotifier {
  SchoolWorkspaceController({
    required SchoolSetupRepository setupRepository,
    required TeachingGroupRepository groupRepository,
    required CreateTeachingGroup createTeachingGroup,
    required StartSchoolYear startSchoolYear,
  }) : _setupRepository = setupRepository,
       _groupRepository = groupRepository,
       _createTeachingGroup = createTeachingGroup,
       _startSchoolYear = startSchoolYear;

  final SchoolSetupRepository _setupRepository;
  final TeachingGroupRepository _groupRepository;
  final CreateTeachingGroup _createTeachingGroup;
  final StartSchoolYear _startSchoolYear;

  InitialSchoolSetup? _setup;
  List<TeachingGroup> _groups = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  InitialSchoolSetup? get setup => _setup;
  List<TeachingGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get canCreateGroup => _setup != null;
  Object? get error => _error;

  Future<void> load(String schoolId) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final setup = await _setupRepository.loadForSchool(schoolId);
      if (setup == null) {
        throw StateError('Selected school setup is missing.');
      }
      _setup = setup;
      await _reloadGroups(setup);
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGroup({
    required String name,
    required Set<PrimaryGrade> grades,
    String? shift,
    ClassSchedule? schedule,
    TeachingContract? contract,
  }) async {
    final setup = _setup;
    if (setup == null || _isSaving || !canCreateGroup) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _createTeachingGroup(
        schoolId: setup.school.id,
        schoolYearId: setup.schoolYear.id,
        name: name,
        grades: grades,
        shift: shift,
        schedule: schedule,
        contract: contract,
      );
      await _reloadGroups(setup);
      SafeLog.operationSuccess('create_group');
      return true;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('create_group', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> startSchoolYear({
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final setup = _setup;
    if (setup == null || _isSaving) return false;

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      await _startSchoolYear(
        schoolId: setup.school.id,
        schoolYearLabel: schoolYearLabel,
        startsOn: startsOn,
        endsOn: endsOn,
      );
      await load(setup.school.id);
      SafeLog.operationSuccess('start_school_year');
      return true;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('start_school_year', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateSchool({
    required String name,
    String? cct,
    String? state,
    String? municipality,
    String? locality,
    String? schoolZone,
    String? schoolSector,
  }) async {
    final setup = _setup;
    if (setup == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final school = School(
        id: setup.school.id,
        name: name,
        cct: cct,
        organization: setup.school.organization,
        state: state,
        municipality: municipality,
        locality: locality,
        schoolZone: schoolZone,
        schoolSector: schoolSector,
      );
      await _setupRepository.updateSchool(school);
      _setup = (school: school, schoolYear: setup.schoolYear);
      SafeLog.operationSuccess('update_school');
      return true;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('update_school', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateGroup({
    required TeachingGroup group,
    required String name,
    required Set<PrimaryGrade> grades,
    String? shift,
    TeachingContract? contract,
  }) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final updated = TeachingGroup(
        id: group.id,
        schoolId: group.schoolId,
        schoolYearId: group.schoolYearId,
        name: name,
        grades: grades,
        shift: shift,
        schedule: group.schedule,
        contract: contract,
      );
      await _groupRepository.save(updated);
      _groups = List<TeachingGroup>.unmodifiable([
        for (final current in _groups)
          if (current.id == updated.id) updated else current,
      ]);
      SafeLog.operationSuccess('update_group');
      return true;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('update_group', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteGroup(TeachingGroup group) async {
    if (_isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _groupRepository.deleteGroup(group.id);
      _groups = List<TeachingGroup>.unmodifiable(
        _groups.where((current) => current.id != group.id),
      );
      SafeLog.operationSuccess('delete_group');
      return true;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('delete_group', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _reloadGroups(InitialSchoolSetup setup) async {
    final allGroups = await _groupRepository.listForSchoolYear(
      setup.schoolYear.id,
    );
    _groups = List<TeachingGroup>.unmodifiable(
      allGroups.where((group) => group.schoolId == setup.school.id),
    );
  }
}
