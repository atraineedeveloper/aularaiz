import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter/foundation.dart';

final class AttendanceStudentRow {
  const AttendanceStudentRow({
    required this.studentId,
    required this.displayName,
    required this.listNumber,
    required this.status,
  });

  final String studentId;
  final String displayName;
  final int listNumber;
  final AttendanceStatus status;
}

final class MonthlyAttendanceStudent {
  const MonthlyAttendanceStudent({
    required this.studentId,
    required this.displayName,
    required this.listNumber,
  });

  final String studentId;
  final String displayName;
  final int listNumber;
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
  DateTime _selectedDate = _today();
  DateTime _selectedMonth = DateTime(_today().year, _today().month);
  DailyAttendance? _attendance;
  List<AttendanceStudentRow> _rows = const [];
  List<DailyAttendance> _monthDays = const [];
  List<MonthlyAttendanceStudent> _monthStudents = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDirty = false;
  Object? _error;

  TeachingGroup? get group => _group;
  DateTime get selectedDate => _selectedDate;
  DateTime get selectedMonth => _selectedMonth;
  DailyAttendance? get attendance => _attendance;
  List<AttendanceStudentRow> get rows => _rows;
  List<DailyAttendance> get monthDays => _monthDays;
  List<MonthlyAttendanceStudent> get monthStudents => _monthStudents;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isDirty => _isDirty;
  Object? get error => _error;

  int count(AttendanceStatus status) => _attendance?.count(status) ?? 0;

  Future<void> load(TeachingGroup group) async {
    _group = group;
    await _loadDate(_selectedDate);
  }

  Future<void> selectDate(DateTime date) async {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _selectedMonth = DateTime(date.year, date.month);
    await _loadDate(_selectedDate);
  }

  Future<void> selectMonth(DateTime month) async {
    _selectedMonth = DateTime(month.year, month.month);
    await _loadMonth();
  }

  void setStatus(String studentId, AttendanceStatus status) {
    final attendance = _attendance;
    if (attendance == null || attendance.statusFor(studentId) == status) return;
    _attendance = attendance.withStatus(studentId, status);
    _rows = [
      for (final row in _rows)
        if (row.studentId == studentId)
          AttendanceStudentRow(
            studentId: row.studentId,
            displayName: row.displayName,
            listNumber: row.listNumber,
            status: status,
          )
        else
          row,
    ];
    _isDirty = true;
    notifyListeners();
  }

  void markAllPresent() {
    var next = _attendance;
    if (next == null || next.entries.isEmpty) return;
    for (final studentId in next.entries.keys) {
      next = next.withStatus(studentId, AttendanceStatus.present);
    }
    _attendance = next;
    _rows = [
      for (final row in _rows)
        AttendanceStudentRow(
          studentId: row.studentId,
          displayName: row.displayName,
          listNumber: row.listNumber,
          status: AttendanceStatus.present,
        ),
    ];
    _isDirty = true;
    notifyListeners();
  }

  Future<bool> save() async {
    final attendance = _attendance;
    if (attendance == null || _isSaving) return false;
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _attendanceRepository.save(attendance);
      _isDirty = false;
      await _loadMonth(notify: false);
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> _loadDate(DateTime date) async {
    final group = _group;
    if (group == null) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _attendance = await _buildDailyAttendance(groupId: group.id, date: date);
      _rows = await _buildRows(group.id, date, _attendance!);
      _isDirty = false;
      await _loadMonth(notify: false);
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<AttendanceStudentRow>> _buildRows(
    String groupId,
    DateTime date,
    DailyAttendance attendance,
  ) async {
    final enrollments = await _enrollmentRepository.findByGroupId(groupId);
    final rows = <AttendanceStudentRow>[];
    for (final entry in attendance.entries.values) {
      final student = await _studentRepository.findById(entry.studentId);
      if (student == null) continue;
      final matching = enrollments.where(
        (enrollment) =>
            enrollment.studentId == entry.studentId && enrollment.isActiveOn(date),
      );
      final listNumber = matching.isEmpty ? 9999 : matching.first.listNumber;
      rows.add(
        AttendanceStudentRow(
          studentId: entry.studentId,
          displayName: student.displayName,
          listNumber: listNumber,
          status: entry.status,
        ),
      );
    }
    rows.sort((left, right) => left.listNumber.compareTo(right.listNumber));
    return List<AttendanceStudentRow>.unmodifiable(rows);
  }

  Future<void> _loadMonth({bool notify = true}) async {
    final group = _group;
    if (group == null) return;
    _monthDays = await _attendanceRepository.listForMonth(
      group.id,
      _selectedMonth,
    );
    final studentIds = <String>{
      for (final day in _monthDays) ...day.entries.keys,
    };
    final enrollments = await _enrollmentRepository.findByGroupId(group.id);
    final students = <MonthlyAttendanceStudent>[];
    for (final studentId in studentIds) {
      final student = await _studentRepository.findById(studentId);
      if (student == null) continue;
      final studentEnrollments = enrollments.where(
        (enrollment) => enrollment.studentId == studentId,
      );
      final listNumber = studentEnrollments.isEmpty
          ? 9999
          : studentEnrollments.first.listNumber;
      students.add(
        MonthlyAttendanceStudent(
          studentId: studentId,
          displayName: student.displayName,
          listNumber: listNumber,
        ),
      );
    }
    students.sort((left, right) => left.listNumber.compareTo(right.listNumber));
    _monthStudents = List<MonthlyAttendanceStudent>.unmodifiable(students);
    if (notify) notifyListeners();
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
