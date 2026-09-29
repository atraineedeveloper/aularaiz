import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/incident_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/incident/incident_category.dart';
import 'package:aularaiz/domain/incident/incident_report.dart';
import 'package:aularaiz/domain/incident/incident_status.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:flutter/foundation.dart';

final class IncidentStudentOption {
  const IncidentStudentOption({
    required this.student,
    required this.groupName,
    required this.gradeLabel,
  });

  final Student student;
  final String groupName;
  final String gradeLabel;
}

final class IncidentReportsController extends ChangeNotifier {
  IncidentReportsController({
    required IncidentRepository incidentRepository,
    required StudentRepository studentRepository,
    required EnrollmentRepository enrollmentRepository,
    required IdGenerator idGenerator,
  }) : _incidentRepository = incidentRepository,
       _studentRepository = studentRepository,
       _enrollmentRepository = enrollmentRepository,
       _idGenerator = idGenerator;

  final IncidentRepository _incidentRepository;
  final StudentRepository _studentRepository;
  final EnrollmentRepository _enrollmentRepository;
  final IdGenerator _idGenerator;

  String? _schoolId;
  List<TeachingGroup> _groups = const [];
  List<IncidentReport> _reports = const [];
  List<IncidentStudentOption> _studentOptions = const [];
  final Map<String, Student> _studentsById = <String, Student>{};
  IncidentStatus? _statusFilter;
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  List<IncidentReport> get reports => _reports;
  List<IncidentStudentOption> get studentOptions => _studentOptions;
  IncidentStatus? get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;

  List<IncidentReport> get visibleReports {
    final filter = _statusFilter;
    if (filter == null) return _reports;
    return _reports.where((report) => report.status == filter).toList();
  }

  String? studentName(String id) => _studentsById[id]?.displayName;

  Future<void> ensureStudentOption(String studentId) async {
    if (_studentOptions.any((option) => option.student.id == studentId)) return;
    final student = await _studentRepository.findById(studentId);
    if (student == null) return;
    _studentsById[student.id] = student;
    _studentOptions = List<IncidentStudentOption>.unmodifiable([
      ..._studentOptions,
      IncidentStudentOption(student: student, groupName: '', gradeLabel: ''),
    ]);
    notifyListeners();
  }

  String? groupName(String? groupId) {
    if (groupId == null) return null;
    for (final group in _groups) {
      if (group.id == groupId) return group.name;
    }
    return null;
  }

  void setStatusFilter(IncidentStatus? value) {
    _statusFilter = value;
    notifyListeners();
  }

  Future<void> load({
    required String schoolId,
    required List<TeachingGroup> groups,
  }) async {
    _schoolId = schoolId;
    _groups = List<TeachingGroup>.unmodifiable(groups);
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _reports = await _incidentRepository.listForSchool(schoolId);
      _studentOptions = await _loadStudentOptions(_groups);
      final linkedIds = _reports.expand((report) => report.studentIds).toSet();
      for (final id in linkedIds) {
        if (_studentsById.containsKey(id)) continue;
        final student = await _studentRepository.findById(id);
        if (student != null) _studentsById[id] = student;
      }
      final activeOptionIds = _studentOptions
          .map((option) => option.student.id)
          .toSet();
      final historicalOptions = <IncidentStudentOption>[
        for (final id in linkedIds)
          if (!activeOptionIds.contains(id) && _studentsById[id] != null)
            IncidentStudentOption(
              student: _studentsById[id]!,
              groupName: '',
              gradeLabel: '',
            ),
      ];
      _studentOptions = List<IncidentStudentOption>.unmodifiable([
        ..._studentOptions,
        ...historicalOptions,
      ]);
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterSync() async {
    final schoolId = _schoolId;
    if (schoolId == null || _isLoading || _isSaving) return;
    await load(schoolId: schoolId, groups: _groups);
  }

  Future<bool> saveReport({
    IncidentReport? existing,
    required String? groupId,
    required DateTime occurredAt,
    required IncidentCategory category,
    required String description,
    required String? actionTaken,
    required String? followUpNote,
    required bool familyNotified,
    required bool leadershipNotified,
    required IncidentStatus status,
    required List<String> studentIds,
  }) async {
    final schoolId = _schoolId;
    if (schoolId == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final report = IncidentReport(
        id: existing?.id ?? _idGenerator.newId(),
        schoolId: schoolId,
        groupId: groupId,
        occurredAt: occurredAt,
        category: category,
        description: description,
        actionTaken: actionTaken,
        followUpNote: followUpNote,
        familyNotified: familyNotified,
        leadershipNotified: leadershipNotified,
        status: status,
        studentIds: studentIds,
        correctedAt: existing == null ? null : DateTime.now(),
      );
      await _incidentRepository.save(report);
      _reports = await _incidentRepository.listForSchool(schoolId);
      for (final option in _studentOptions) {
        _studentsById[option.student.id] = option.student;
      }
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<List<IncidentStudentOption>> _loadStudentOptions(
    List<TeachingGroup> groups,
  ) async {
    final optionsByStudent = <String, IncidentStudentOption>{};
    final today = DateTime.now();
    for (final group in groups) {
      final enrollments = await _enrollmentRepository.findByGroupId(group.id);
      for (final enrollment in enrollments.where(
        (item) => item.isActiveOn(today),
      )) {
        if (optionsByStudent.containsKey(enrollment.studentId)) continue;
        final student = await _studentRepository.findById(enrollment.studentId);
        if (student == null) continue;
        _studentsById[student.id] = student;
        optionsByStudent[student.id] = IncidentStudentOption(
          student: student,
          groupName: group.name,
          gradeLabel: '${enrollment.grade.number}.º',
        );
      }
    }
    final options = optionsByStudent.values.toList()
      ..sort(
        (left, right) =>
            left.student.displayName.compareTo(right.student.displayName),
      );
    return List<IncidentStudentOption>.unmodifiable(options);
  }
}
