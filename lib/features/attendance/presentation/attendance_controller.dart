import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:flutter/foundation.dart';

final class MonthlyAttendanceStudent {
  const MonthlyAttendanceStudent({
    required this.studentId,
    required this.displayName,
    required this.listNumber,
    required this.grades,
  });

  final String studentId;
  final String displayName;
  final int listNumber;
  final Set<PrimaryGrade> grades;
  String get gradeLabel =>
      (grades.toList()..sort((a, b) => a.number.compareTo(b.number)))
          .map((g) => '${g.number}.º')
          .join(' / ');
}

final class MonthlyAttendanceSummary {
  const MonthlyAttendanceSummary({
    required this.recorded,
    required this.present,
    required this.absent,
    required this.late,
    required this.justified,
  });

  final int recorded;
  final int present;
  final int absent;
  final int late;
  final int justified;

  int get attended => present + late;
  double? get rate => recorded == 0 ? null : attended / recorded;
}

final class AttendanceController extends ChangeNotifier {
  AttendanceController({
    required AttendanceRepository attendanceRepository,
    required EnrollmentRepository enrollmentRepository,
    required StudentRepository studentRepository,
    required BuildDailyAttendance buildDailyAttendance,
  }) : _attendanceRepository = attendanceRepository,
       _enrollmentRepository = enrollmentRepository,
       _studentRepository = studentRepository,
       _buildDailyAttendance = buildDailyAttendance;

  final AttendanceRepository _attendanceRepository;
  final EnrollmentRepository _enrollmentRepository;
  final StudentRepository _studentRepository;
  final BuildDailyAttendance _buildDailyAttendance;

  TeachingGroup? _group;
  DateTime _selectedMonth = DateTime(_today().year, _today().month);
  List<DailyAttendance> _savedMonthDays = const [];
  List<Enrollment> _enrollments = const [];
  List<MonthlyAttendanceStudent> _monthStudents = const [];
  final Map<DateTime, DailyAttendance> _draftDays = {};
  final Set<DateTime> _dirtyDates = {};
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  TeachingGroup? get group => _group;
  DateTime get selectedMonth => _selectedMonth;
  List<MonthlyAttendanceStudent> get monthStudents => _monthStudents;
  PrimaryGrade? selectedGrade;
  bool groupByGrade = false;
  List<PrimaryGrade> get availableGrades => ({
    ...?_group?.grades,
    for (final student in _monthStudents) ...student.grades,
  }.toList()..sort((a, b) => a.number.compareTo(b.number)));
  List<MonthlyAttendanceStudent> get visibleStudents {
    final result = _monthStudents
        .where((s) => selectedGrade == null || s.grades.contains(selectedGrade))
        .toList();
    if (groupByGrade) {
      result.sort((a, b) {
        final grade = a.gradeLabel.compareTo(b.gradeLabel);
        return grade != 0 ? grade : a.listNumber.compareTo(b.listNumber);
      });
    }
    return result;
  }

  void setGrade(PrimaryGrade? grade) {
    selectedGrade = grade;
    notifyListeners();
  }

  void setGroupByGrade(bool value) {
    groupByGrade = value;
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isDirty => _dirtyDates.isNotEmpty;
  Object? get error => _error;

  List<DateTime> get monthDates {
    final lastDay = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    return List<DateTime>.unmodifiable([
      for (var day = 1; day <= lastDay; day++)
        if (_isWeekday(
          DateTime(_selectedMonth.year, _selectedMonth.month, day),
        ))
          DateTime(_selectedMonth.year, _selectedMonth.month, day),
    ]);
  }

  int get recordedDays {
    final dates = <DateTime>{
      for (final day in _savedMonthDays) _normalize(day.date),
      ..._draftDays.keys,
    };
    return dates.length;
  }

  MonthlyAttendanceSummary summaryFor(String studentId) {
    var present = 0;
    var absent = 0;
    var late = 0;
    var justified = 0;

    for (final date in monthDates) {
      if (!isStudentActiveOn(studentId, date)) continue;
      final status = statusFor(studentId, date);
      if (status == null) continue;
      switch (status) {
        case AttendanceStatus.present:
          present += 1;
        case AttendanceStatus.absent:
          absent += 1;
        case AttendanceStatus.late:
          late += 1;
        case AttendanceStatus.justifiedAbsence:
          justified += 1;
      }
    }

    return MonthlyAttendanceSummary(
      recorded: present + absent + late + justified,
      present: present,
      absent: absent,
      late: late,
      justified: justified,
    );
  }

  MonthlyAttendanceSummary get groupSummary {
    var recorded = 0;
    var present = 0;
    var absent = 0;
    var late = 0;
    var justified = 0;
    for (final student in _monthStudents) {
      final summary = summaryFor(student.studentId);
      recorded += summary.recorded;
      present += summary.present;
      absent += summary.absent;
      late += summary.late;
      justified += summary.justified;
    }
    return MonthlyAttendanceSummary(
      recorded: recorded,
      present: present,
      absent: absent,
      late: late,
      justified: justified,
    );
  }

  Future<void> load(TeachingGroup group) async {
    _group = group;
    await _loadMonth();
  }

  Future<void> selectMonth(DateTime month) async {
    _selectedMonth = DateTime(month.year, month.month);
    await _loadMonth();
  }

  bool isStudentActiveOn(String studentId, DateTime date) {
    return _enrollments.any(
      (enrollment) =>
          enrollment.studentId == studentId && enrollment.isActiveOn(date),
    );
  }

  AttendanceStatus? statusFor(String studentId, DateTime date) {
    return _attendanceFor(date)?.statusFor(studentId);
  }

  bool hasAttendanceFor(DateTime date) => _attendanceFor(date) != null;

  MonthlyAttendanceSummary? daySummary(DateTime date) {
    final day = _attendanceFor(date);
    if (day == null) return null;
    return MonthlyAttendanceSummary(
      recorded: day.entries.length,
      present: day.count(AttendanceStatus.present),
      late: day.count(AttendanceStatus.late),
      absent: day.count(AttendanceStatus.absent),
      justified: day.count(AttendanceStatus.justifiedAbsence),
    );
  }

  Future<bool> deleteDay(DateTime date) async {
    final group = _group;
    if (group == null || _isSaving || _isLoading) return false;
    final normalized = _normalize(date);
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final repository = _attendanceRepository;
      if (repository is! DeletableAttendanceRepository) {
        throw UnsupportedError('Attendance deletion is not supported.');
      }
      await (repository as DeletableAttendanceRepository).deleteByGroupAndDate(
        group.id,
        normalized,
      );
      _savedMonthDays = _savedMonthDays
          .where((day) => _normalize(day.date) != normalized)
          .toList();
      _draftDays.remove(normalized);
      _dirtyDates.remove(normalized);
      SafeLog.operationSuccess('delete_attendance_day');
      return true;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('delete_attendance_day', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  bool isDateDirty(DateTime date) => _dirtyDates.contains(_normalize(date));

  Future<void> markDayPresent(DateTime date) async {
    if (_isSaving || _isLoading) return;
    final attendance = await _ensureDraft(date);
    if (attendance == null || attendance.entries.isEmpty) return;

    var next = attendance;
    for (final studentId in attendance.entries.keys) {
      next = next.withStatus(studentId, AttendanceStatus.present);
    }
    final normalized = _normalize(date);
    _draftDays[normalized] = next;
    _dirtyDates.add(normalized);
    notifyListeners();
  }

  Future<void> setMonthStatus(
    String studentId,
    DateTime date,
    AttendanceStatus status,
  ) async {
    if (_isSaving || _isLoading) return;
    final normalized = _normalize(date);
    final attendance = await _ensureDraft(normalized);
    if (attendance == null || attendance.statusFor(studentId) == null) return;
    if (attendance.statusFor(studentId) == status &&
        _dirtyDates.contains(normalized)) {
      return;
    }

    _draftDays[normalized] = attendance.withStatus(studentId, status);
    _dirtyDates.add(normalized);
    notifyListeners();
  }

  Future<bool> saveMonth() async {
    if (_isSaving || _dirtyDates.isEmpty) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final dates = _dirtyDates.toList()..sort();
      for (final date in dates) {
        final attendance = _draftDays[date];
        if (attendance != null) await _attendanceRepository.save(attendance);
      }
      await _loadMonth(notify: false);
      SafeLog.operationSuccess('save_attendance');
      return true;
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('save_attendance', error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> discardChanges() async {
    await _loadMonth();
  }

  Future<DailyAttendance?> _ensureDraft(DateTime date) async {
    final group = _group;
    if (group == null) return null;
    final normalized = _normalize(date);
    final current = _attendanceFor(normalized);
    if (current != null) {
      _draftDays.putIfAbsent(normalized, () => current);
      return _draftDays[normalized];
    }

    final built = await _buildDailyAttendance(
      groupId: group.id,
      date: normalized,
    );
    if (built.entries.isEmpty) return null;
    _draftDays[normalized] = built;
    return built;
  }

  DailyAttendance? _attendanceFor(DateTime date) {
    final normalized = _normalize(date);
    final draft = _draftDays[normalized];
    if (draft != null) return draft;
    for (final day in _savedMonthDays) {
      if (_normalize(day.date) == normalized) return day;
    }
    return null;
  }

  Future<void> _loadMonth({bool notify = true}) async {
    final group = _group;
    if (group == null) return;
    _isLoading = true;
    _error = null;
    if (notify) notifyListeners();
    try {
      _savedMonthDays = await _attendanceRepository.listForMonth(
        group.id,
        _selectedMonth,
      );
      _draftDays.clear();
      _dirtyDates.clear();
      _enrollments = await _enrollmentRepository.findByGroupId(group.id);
      _monthStudents = await _buildMonthStudents();
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('load_attendance', error);
    } finally {
      _isLoading = false;
      if (notify) notifyListeners();
    }
  }

  Future<List<MonthlyAttendanceStudent>> _buildMonthStudents() async {
    final first = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final last = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final overlapping = _enrollments.where((enrollment) {
      if (enrollment.startsOn.isAfter(last)) return false;
      final end = enrollment.endsOn;
      return end == null || !end.isBefore(first);
    }).toList();

    final byStudent = <String, List<Enrollment>>{};
    for (final enrollment in overlapping) {
      byStudent.putIfAbsent(enrollment.studentId, () => []).add(enrollment);
    }

    final students = <MonthlyAttendanceStudent>[];
    for (final entry in byStudent.entries) {
      final student = await _studentRepository.findById(entry.key);
      if (student == null) continue;
      entry.value.sort(
        (left, right) => left.startsOn.compareTo(right.startsOn),
      );
      students.add(
        MonthlyAttendanceStudent(
          studentId: entry.key,
          displayName: student.displayName,
          listNumber: entry.value.first.listNumber,
          grades: entry.value.map((e) => e.grade).toSet(),
        ),
      );
    }
    students.sort((left, right) {
      final byNumber = left.listNumber.compareTo(right.listNumber);
      return byNumber != 0
          ? byNumber
          : left.displayName.compareTo(right.displayName);
    });
    return List<MonthlyAttendanceStudent>.unmodifiable(students);
  }

  static DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static bool _isWeekday(DateTime date) =>
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
