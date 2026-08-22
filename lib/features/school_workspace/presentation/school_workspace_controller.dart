import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/class_schedule.dart';
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
  Object? get error => _error;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final setup = await _setupRepository.loadInitialSetup();
      if (setup == null) {
        throw StateError('Initial school setup is missing.');
      }
      _setup = setup;
      _groups = await _groupRepository.listForSchoolYear(setup.schoolYear.id);
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
    if (setup == null || _isSaving) return false;

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
      _groups = await _groupRepository.listForSchoolYear(setup.schoolYear.id);
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
