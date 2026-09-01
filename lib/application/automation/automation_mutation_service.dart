import 'package:aularaiz/application/attendance/set_student_attendance_status.dart';
import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/project/create_activity.dart';
import 'package:aularaiz/application/project/create_project.dart';
import 'package:aularaiz/application/school_setup/create_initial_workspace.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/application/student/deactivate_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/activity.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project.dart';
import 'package:aularaiz/domain/project/project_lifecycle.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/domain/student/student_sex.dart';

typedef AutomationMutationClock = DateTime Function();

final class AutomationMutationService {
  AutomationMutationService({
    required TeachingGroupRepository teachingGroupRepository,
    required StudentRepository studentRepository,
    required EnrollmentRepository enrollmentRepository,
    required SetStudentAttendanceStatus setStudentAttendanceStatus,
    required DeactivateStudentInGroup deactivateStudentInGroup,
    required ReactivateStudentInGroup reactivateStudentInGroup,
    required SchoolSetupRepository schoolSetupRepository,
    required CreateInitialWorkspace createInitialWorkspace,
    required CreateTeachingGroup createTeachingGroup,
    required CreateStudentInGroup createStudentInGroup,
    required CreateProject createProject,
    required CreateActivity createActivity,
    required ProjectRepository projectRepository,
    required ActivityRepository activityRepository,
    AutomationMutationClock? clock,
  }) : _teachingGroupRepository = teachingGroupRepository,
       _studentRepository = studentRepository,
       _enrollmentRepository = enrollmentRepository,
       _setStudentAttendanceStatus = setStudentAttendanceStatus,
       _deactivateStudentInGroup = deactivateStudentInGroup,
       _reactivateStudentInGroup = reactivateStudentInGroup,
       _schoolSetupRepository = schoolSetupRepository,
       _createInitialWorkspace = createInitialWorkspace,
       _createTeachingGroup = createTeachingGroup,
       _createStudentInGroup = createStudentInGroup,
       _createProject = createProject,
       _createActivity = createActivity,
       _projectRepository = projectRepository,
       _activityRepository = activityRepository,
       _clock = clock ?? DateTime.now;

  final TeachingGroupRepository _teachingGroupRepository;
  final StudentRepository _studentRepository;
  final EnrollmentRepository _enrollmentRepository;
  final SetStudentAttendanceStatus _setStudentAttendanceStatus;
  final DeactivateStudentInGroup _deactivateStudentInGroup;
  final ReactivateStudentInGroup _reactivateStudentInGroup;
  final SchoolSetupRepository _schoolSetupRepository;
  final CreateInitialWorkspace _createInitialWorkspace;
  final CreateTeachingGroup _createTeachingGroup;
  final CreateStudentInGroup _createStudentInGroup;
  final CreateProject _createProject;
  final CreateActivity _createActivity;
  final ProjectRepository _projectRepository;
  final ActivityRepository _activityRepository;
  final AutomationMutationClock _clock;

  Future<AutomationEnvelope> createWorkspace({
    required String schoolName,
    String? cct,
    required SchoolOrganization organization,
    String? state,
    String? municipality,
    String? locality,
    required String schoolYearLabel,
    required DateTime startsOn,
    required DateTime endsOn,
    required String groupName,
    required Set<PrimaryGrade> grades,
    String? shift,
    bool apply = false,
  }) async {
    if (apply) {
      await _createInitialWorkspace(
        schoolName: schoolName,
        cct: cct,
        organization: organization,
        state: state,
        municipality: municipality,
        locality: locality,
        schoolYearLabel: schoolYearLabel,
        startsOn: startsOn,
        endsOn: endsOn,
        groupName: groupName,
        grades: grades,
        shift: shift,
      );
    }
    return _envelope(
      kind: 'workspace-create',
      privacy: const AutomationPrivacy(),
      data: {
        'dry_run': !apply,
        'applied': apply,
        'school_name': schoolName.trim(),
        'school_year': schoolYearLabel.trim(),
        'group_name': groupName.trim(),
        'grades': grades.map((grade) => grade.number).toList()..sort(),
        if (shift?.trim().isNotEmpty == true) 'shift': shift!.trim(),
      },
    );
  }

  Future<AutomationEnvelope> updateSchool({
    required String schoolId,
    required String name,
    String? cct,
    String? state,
    String? municipality,
    String? locality,
    bool apply = false,
  }) async {
    final setup = await _schoolSetupRepository.loadForSchool(schoolId);
    if (setup == null) throw StateError('School does not exist.');
    final updated = School(
      id: setup.school.id,
      name: name,
      cct: cct,
      organization: setup.school.organization,
      state: state,
      municipality: municipality,
      locality: locality,
    );
    if (apply) await _schoolSetupRepository.updateSchool(updated);
    return _envelope(
      kind: 'school-update',
      privacy: const AutomationPrivacy(),
      data: {'dry_run': !apply, 'applied': apply, 'school_id': schoolId},
    );
  }

  Future<AutomationEnvelope> deleteSchool({
    required String schoolId,
    bool apply = false,
  }) async {
    final setup = await _schoolSetupRepository.loadForSchool(schoolId);
    if (setup == null) throw StateError('School does not exist.');
    if (apply) await _schoolSetupRepository.deleteSchool(schoolId);
    return _envelope(
      kind: 'school-delete',
      privacy: const AutomationPrivacy(),
      data: {'dry_run': !apply, 'applied': apply, 'school_id': schoolId},
    );
  }

  Future<AutomationEnvelope> createGroup({
    required String schoolId,
    required String schoolYearId,
    required String name,
    required Set<PrimaryGrade> grades,
    String? shift,
    bool apply = false,
  }) async {
    TeachingGroup? group;
    if (apply) {
      group = await _createTeachingGroup(
        schoolId: schoolId,
        schoolYearId: schoolYearId,
        name: name,
        grades: grades,
        shift: shift,
      );
    }
    return _envelope(
      kind: 'group-create',
      privacy: const AutomationPrivacy(),
      data: {
        'dry_run': !apply,
        'applied': apply,
        if (group != null) 'group': _groupProjection(group),
        if (group == null) 'name': name.trim(),
      },
    );
  }

  Future<AutomationEnvelope> deleteGroup({
    required String groupId,
    bool apply = false,
  }) async {
    final group = await _requireGroup(groupId);
    if (apply) await _teachingGroupRepository.deleteGroup(group.id);
    return _envelope(
      kind: 'group-delete',
      privacy: const AutomationPrivacy(),
      data: {
        'dry_run': !apply,
        'applied': apply,
        'group': _groupProjection(group),
      },
    );
  }

  Future<AutomationEnvelope> updateGroup({
    required String groupId,
    required String name,
    required Set<PrimaryGrade> grades,
    String? shift,
    bool apply = false,
  }) async {
    final current = await _requireGroup(groupId);
    final updated = TeachingGroup(
      id: current.id,
      schoolId: current.schoolId,
      schoolYearId: current.schoolYearId,
      name: name,
      grades: grades,
      shift: shift,
      schedule: current.schedule,
      contract: current.contract,
    );
    if (apply) await _teachingGroupRepository.save(updated);
    return _envelope(
      kind: 'group-update',
      privacy: const AutomationPrivacy(),
      data: {
        'dry_run': !apply,
        'applied': apply,
        'group': _groupProjection(updated),
      },
    );
  }

  Future<AutomationEnvelope> createStudent({
    required String groupId,
    required String givenNames,
    required String firstSurname,
    String? secondSurname,
    StudentSex? sex,
    DateTime? birthDate,
    required PrimaryGrade grade,
    required int listNumber,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    if (!group.acceptsGrade(grade)) {
      throw StateError('Grade is not offered by the group.');
    }
    if (listNumber <= 0) throw StateError('List number must be positive.');
    Student? student;
    if (apply) {
      final result = await _createStudentInGroup(
        groupId: group.id,
        givenNames: givenNames,
        firstSurname: firstSurname,
        secondSurname: secondSurname,
        sex: sex,
        birthDate: birthDate,
        grade: grade,
        listNumber: listNumber,
      );
      switch (result) {
        case CreateStudentInGroupSucceeded(student: final created):
          student = created;
          break;
        case CreateStudentInGroupRejected(:final violations):
          throw StateError(
            'Student enrollment rejected: ${violations.map((v) => v.name).join(', ')}',
          );
      }
    }
    return _envelope(
      kind: 'student-create',
      privacy: privacy,
      data: {
        'dry_run': !apply,
        'applied': apply,
        'group_id': group.id,
        'grade': grade.number,
        'list_number': listNumber,
        if (privacy.includePersonalData && student != null)
          'student': _personalStudentIdentity(student),
      },
    );
  }

  Future<AutomationEnvelope> updateStudent({
    required String studentId,
    required String givenNames,
    required String firstSurname,
    String? secondSurname,
    StudentSex? sex,
    DateTime? birthDate,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final current = await _requireStudent(studentId);
    final updated = Student(
      id: current.id,
      givenNames: givenNames,
      firstSurname: firstSurname,
      secondSurname: secondSurname,
      sex: sex,
      birthDate: birthDate,
    );
    if (apply) await _studentRepository.save(updated);
    return _envelope(
      kind: 'student-update',
      privacy: privacy,
      data: {
        'dry_run': !apply,
        'applied': apply,
        'student_id': studentId,
        if (privacy.includePersonalData)
          'student': _personalStudentIdentity(updated),
      },
    );
  }

  Future<AutomationEnvelope> createProject({
    required String groupId,
    required String title,
    required ProjectMethodology methodology,
    required Set<PrimaryGrade> grades,
    bool apply = false,
  }) async {
    await _requireGroup(groupId);
    Project project;
    if (apply) {
      project = await _createProject(
        groupId: groupId,
        title: title,
        methodology: methodology,
        targetGrades: grades,
      );
    } else {
      project = Project(
        id: 'dry-run',
        groupId: groupId,
        title: title,
        lifecycle: ProjectLifecycle.draft,
        methodology: methodology,
        targetGrades: grades,
      );
    }
    return _envelope(
      kind: 'project-create',
      privacy: const AutomationPrivacy(),
      data: {
        'dry_run': !apply,
        'applied': apply,
        'project_id': project.id,
        'group_id': groupId,
        'title': project.title,
      },
    );
  }

  Future<AutomationEnvelope> updateProject({
    required String projectId,
    required String title,
    required ProjectMethodology methodology,
    required Set<PrimaryGrade> grades,
    bool apply = false,
  }) async {
    final current = await _projectRepository.findById(projectId);
    if (current == null) throw StateError('Project does not exist.');
    final updated = Project(
      id: current.id,
      groupId: current.groupId,
      title: title,
      description: current.description,
      startsOn: current.startsOn,
      endsOn: current.endsOn,
      observations: current.observations,
      lifecycle: current.lifecycle,
      methodology: methodology,
      articulatingAxes: current.articulatingAxes,
      targetGrades: grades,
    );
    if (apply) await _projectRepository.save(updated);
    return _envelope(
      kind: 'project-update',
      privacy: const AutomationPrivacy(),
      data: {'dry_run': !apply, 'applied': apply, 'project_id': projectId},
    );
  }

  Future<AutomationEnvelope> createActivity({
    required String projectId,
    required String title,
    required FormativeField formativeField,
    required Set<PrimaryGrade> grades,
    required DateTime occursOn,
    bool apply = false,
  }) async {
    final project = await _projectRepository.findById(projectId);
    if (project == null) throw StateError('Project does not exist.');
    if (!project.allowsActivityGrades(grades)) {
      throw StateError('Activity grades must be inside project scope.');
    }
    Activity? activity;
    if (apply) {
      activity = await _createActivity(
        projectId: projectId,
        title: title,
        formativeField: formativeField,
        targetGrades: grades,
        occursOn: occursOn,
      );
    }
    return _envelope(
      kind: 'activity-create',
      privacy: const AutomationPrivacy(),
      data: {
        'dry_run': !apply,
        'applied': apply,
        'project_id': projectId,
        if (activity != null) 'activity_id': activity.id,
        'title': title.trim(),
      },
    );
  }

  Future<AutomationEnvelope> deleteActivity({
    required String activityId,
    bool apply = false,
  }) async {
    final activity = await _activityRepository.findById(activityId);
    if (activity == null) throw StateError('Activity does not exist.');
    if (apply) await _activityRepository.deleteActivity(activityId);
    return _envelope(
      kind: 'activity-delete',
      privacy: const AutomationPrivacy(),
      data: {'dry_run': !apply, 'applied': apply, 'activity_id': activityId},
    );
  }

  Future<AutomationEnvelope> setAttendance({
    required String groupId,
    required String studentId,
    required DateTime date,
    required AttendanceStatus status,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final student = await _requireStudent(studentId);
    final change = apply
        ? await _setStudentAttendanceStatus(
            groupId: group.id,
            studentId: student.id,
            date: date,
            status: status,
          )
        : await _setStudentAttendanceStatus.preview(
            groupId: group.id,
            studentId: student.id,
            date: date,
            status: status,
          );

    return _envelope(
      kind: 'attendance-set',
      privacy: privacy,
      data: <String, Object?>{
        'operation': 'set-attendance-status',
        'dry_run': !apply,
        'applied': apply,
        'group': _groupProjection(group),
        'date': _dateLabel(change.attendance.date),
        'previous_status': _attendanceStatusLabel(change.previousStatus),
        'status': _attendanceStatusLabel(change.status),
        if (privacy.includePersonalData)
          'student': _personalStudentIdentity(student),
      },
    );
  }

  Future<AutomationEnvelope> deactivateStudent({
    required String groupId,
    required String studentId,
    required DateTime endsOn,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final student = await _requireStudent(studentId);
    final plan = apply
        ? await _deactivateStudentInGroup(
            studentId: student.id,
            groupId: group.id,
            endsOn: endsOn,
          )
        : await _deactivateStudentInGroup.preview(
            studentId: student.id,
            groupId: group.id,
            endsOn: endsOn,
          );

    return _envelope(
      kind: 'student-deactivate',
      privacy: privacy,
      data: <String, Object?>{
        'operation': 'deactivate-student-in-group',
        'dry_run': !apply,
        'applied': apply,
        'group': _groupProjection(group),
        'ends_on': _dateLabel(plan.endsOn),
        'grade': plan.currentEnrollment.grade.number,
        if (privacy.includePersonalData) ...<String, Object?>{
          'student': _personalStudentIdentity(student),
          'list_number': plan.currentEnrollment.listNumber,
        },
      },
    );
  }

  Future<AutomationEnvelope> reactivateStudent({
    required String groupId,
    required String studentId,
    required PrimaryGrade grade,
    required int listNumber,
    DateTime? startsOn,
    bool apply = false,
    AutomationPrivacy privacy = const AutomationPrivacy(),
  }) async {
    final group = await _requireGroup(groupId);
    final student = await _requireStudent(studentId);
    final previous = await _latestEnrollment(
      groupId: group.id,
      studentId: student.id,
    );
    final previousEnd = previous.endsOn;
    if (previousEnd == null) {
      throw StateError(
        'Student already has an active enrollment in this group.',
      );
    }

    final effectiveStart = startsOn == null
        ? _date(previousEnd.add(const Duration(days: 1)))
        : _date(startsOn);
    final result = apply
        ? await _reactivateStudentInGroup(
            studentId: student.id,
            groupId: group.id,
            grade: grade,
            listNumber: listNumber,
            startsOn: effectiveStart,
          )
        : await _reactivateStudentInGroup.preview(
            studentId: student.id,
            groupId: group.id,
            grade: grade,
            listNumber: listNumber,
            startsOn: effectiveStart,
          );
    _requireEnrollmentSuccess(result);

    return _envelope(
      kind: 'student-reactivate',
      privacy: privacy,
      data: <String, Object?>{
        'operation': 'reactivate-student-in-group',
        'dry_run': !apply,
        'applied': apply,
        'group': _groupProjection(group),
        'starts_on': _dateLabel(effectiveStart),
        'grade': grade.number,
        if (privacy.includePersonalData) ...<String, Object?>{
          'student': _personalStudentIdentity(student),
          'list_number': listNumber,
        },
      },
    );
  }

  Future<TeachingGroup> _requireGroup(String groupId) async {
    final normalized = groupId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        groupId,
        'groupId',
        'Group id cannot be empty.',
      );
    }
    final group = await _teachingGroupRepository.findById(normalized);
    if (group == null) throw StateError('Teaching group does not exist.');
    return group;
  }

  Future<Student> _requireStudent(String studentId) async {
    final normalized = studentId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(
        studentId,
        'studentId',
        'Student id cannot be empty.',
      );
    }
    final student = await _studentRepository.findById(normalized);
    if (student == null) throw StateError('Student does not exist.');
    return student;
  }

  Future<Enrollment> _latestEnrollment({
    required String groupId,
    required String studentId,
  }) async {
    final matches =
        (await _enrollmentRepository.findByGroupId(groupId))
            .where((enrollment) => enrollment.studentId == studentId)
            .toList(growable: false)
          ..sort((left, right) => right.startsOn.compareTo(left.startsOn));
    if (matches.isEmpty) {
      throw StateError('Student has no enrollment history in this group.');
    }
    return matches.first;
  }

  void _requireEnrollmentSuccess(EnrollStudentResult result) {
    switch (result) {
      case EnrollStudentSucceeded():
        return;
      case EnrollStudentMissingReference(:final reference):
        throw StateError('Missing enrollment reference: ${reference.name}.');
      case EnrollStudentRejected(:final violations):
        final codes = violations.map((violation) => violation.name).join(', ');
        throw StateError('Enrollment policy rejected reactivation: $codes.');
    }
  }

  AutomationEnvelope _envelope({
    required String kind,
    required AutomationPrivacy privacy,
    required Map<String, Object?> data,
  }) {
    return AutomationEnvelope(
      kind: kind,
      privacy: privacy,
      data: data,
      generatedAt: _clock(),
    );
  }
}

Map<String, Object?> _groupProjection(TeachingGroup group) => <String, Object?>{
  'id': group.id,
  'name': group.name,
  'grades': group.grades.map((grade) => grade.number).toList(growable: false)
    ..sort(),
  'multigrade': group.isMultigrade,
  if (group.shift != null) 'shift': group.shift,
};

Map<String, Object?> _personalStudentIdentity(Student student) =>
    <String, Object?>{'student_id': student.id, 'name': student.displayName};

String _attendanceStatusLabel(AttendanceStatus status) => switch (status) {
  AttendanceStatus.present => 'present',
  AttendanceStatus.absent => 'absent',
  AttendanceStatus.late => 'late',
  AttendanceStatus.justifiedAbsence => 'justified-absence',
};

DateTime _date(DateTime value) => DateTime(value.year, value.month, value.day);

String _dateLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
