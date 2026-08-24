import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter/foundation.dart';

final class SchoolWorkspaceController extends ChangeNotifier {
  SchoolWorkspaceController({
    required SchoolSetupRepository setupRepository,
    required TeachingGroupRepository groupRepository,
    required CreateTeachingGroup createTeachingGroup,
  }) : _setupRepository = setupRepository,
       _groupRepository = groupRepository,
       _createTeachingGroup = createTeachingGroup;

  final SchoolSetupRepository _setupRepository;
  final TeachingGroupRepository _groupRepository;
  final CreateTeachingGroup _createTeachingGroup;

  InitialSchoolSetup? _setup;
  List<TeachingGroup> _groups = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  InitialSchoolSetup? get setup => _setup;
  List<TeachingGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get canCreateGroup => _groups.isEmpty;
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
      );
      await _reloadGroups(setup);
      return true;
    } catch (error) {
      _error = error;
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
      );
      await _setupRepository.updateSchool(school);
      _setup = (school: school, schoolYear: setup.schoolYear);
      return true;
    } catch (error) {
      _error = error;
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
      );
      await _groupRepository.save(updated);
      _groups = List<TeachingGroup>.unmodifiable([
        for (final current in _groups)
          if (current.id == updated.id) updated else current,
      ]);
      return true;
    } catch (error) {
      _error = error;
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
      return true;
    } catch (error) {
      _error = error;
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
