import 'package:aularaiz/application/contracts/teacher_attendance_repository.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_record.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_schedule.dart';
import 'package:flutter/foundation.dart';

final class TeacherAttendanceController extends ChangeNotifier {
  TeacherAttendanceController({required TeacherAttendanceRepository repository})
    : _repository = repository;

  final TeacherAttendanceRepository _repository;

  String? _schoolId;
  List<TeacherAttendanceRecord> _records = const [];
  TeacherAttendanceSchedule? _schedule;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = false;
  bool _isSaving = false;
  Object? _error;

  List<TeacherAttendanceRecord> get records => _records;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  Object? get error => _error;
  TeacherAttendanceSchedule? get schedule => _schedule;
  DateTime get selectedMonth => _selectedMonth;

  List<TeacherAttendanceRecord> get monthRecords => _records
      .where(
        (record) =>
            record.attendanceDate.year == _selectedMonth.year &&
            record.attendanceDate.month == _selectedMonth.month,
      )
      .toList(growable: false);

  int get lateCount => monthRecords
      .where((record) => _schedule?.isLate(record.arrivedAt) ?? false)
      .length;

  int get incompleteCount => monthRecords.where(isIncomplete).length;

  Duration get totalWorked => monthRecords.fold(Duration.zero, (total, record) {
    final departure = record.departedAt;
    return departure == null
        ? total
        : total + departure.difference(record.arrivedAt);
  });

  bool isLate(TeacherAttendanceRecord record) =>
      record.expectedArrivalMinute != null &&
      (record.arrivedAt.hour * 60 + record.arrivedAt.minute) >
          record.expectedArrivalMinute! + (record.arrivalGraceMinutes ?? 0);

  bool isIncomplete(TeacherAttendanceRecord record) => record.departedAt == null
      ? _isBeforeToday(record.attendanceDate)
      : record.expectedDepartureMinute != null &&
            record.departedAt!.hour * 60 + record.departedAt!.minute <
                record.expectedDepartureMinute!;

  TeacherAttendanceRecord? get todayRecord {
    final today = _today();
    for (final record in _records) {
      if (_sameDate(record.attendanceDate, today)) return record;
    }
    return null;
  }

  Future<void> load(String schoolId) async {
    _schoolId = schoolId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _records = await _repository.listForSchool(schoolId);
      _schedule = await _repository.loadSchedule(schoolId);
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterSync() async {
    final schoolId = _schoolId;
    if (schoolId != null) await load(schoolId);
  }

  void previousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    notifyListeners();
  }

  Future<bool> saveSchedule({
    required int? expectedArrivalMinute,
    required int? expectedDepartureMinute,
    required int arrivalGraceMinutes,
  }) async {
    final schoolId = _schoolId;
    if (schoolId == null || _isSaving) return false;
    final schedule = TeacherAttendanceSchedule(
      schoolId: schoolId,
      expectedArrivalMinute: expectedArrivalMinute,
      expectedDepartureMinute: expectedDepartureMinute,
      arrivalGraceMinutes: arrivalGraceMinutes,
    );
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.saveSchedule(schedule);
      _schedule = schedule;
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> registerArrival() async {
    final schoolId = _schoolId;
    if (schoolId == null || _isSaving) return false;
    final now = DateTime.now();
    TeacherAttendanceRecord? current;
    try {
      current = await _repository.findForDate(schoolId, now);
    } catch (error) {
      _error = error;
      notifyListeners();
      return false;
    }
    if (current != null) return false;
    return _save(
      TeacherAttendanceRecord(
        id: _recordId(schoolId, now),
        schoolId: schoolId,
        attendanceDate: now,
        arrivedAt: now,
        expectedArrivalMinute: _schedule?.expectedArrivalMinute,
        expectedDepartureMinute: _schedule?.expectedDepartureMinute,
        arrivalGraceMinutes: _schedule?.isConfigured == true
            ? _schedule!.arrivalGraceMinutes
            : null,
      ),
    );
  }

  Future<bool> registerDeparture() async {
    final current = todayRecord;
    if (current == null || !current.isOpen || _isSaving) return false;
    return _save(current.copyWith(departedAt: DateTime.now()));
  }

  Future<bool> addPastRecord({
    required DateTime date,
    required DateTime arrivedAt,
    required DateTime? departedAt,
    required String? notes,
  }) async {
    final schoolId = _schoolId;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (schoolId == null || _isSaving || !_isBeforeToday(normalizedDate)) {
      return false;
    }
    TeacherAttendanceRecord? existing;
    try {
      existing = await _repository.findForDate(schoolId, normalizedDate);
    } catch (error) {
      _error = error;
      notifyListeners();
      return false;
    }
    if (existing != null) return false;
    return _save(
      TeacherAttendanceRecord(
        id: _recordId(schoolId, normalizedDate),
        schoolId: schoolId,
        attendanceDate: normalizedDate,
        arrivedAt: arrivedAt,
        departedAt: departedAt,
        notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
        correctedAt: DateTime.now(),
        expectedArrivalMinute: _schedule?.expectedArrivalMinute,
        expectedDepartureMinute: _schedule?.expectedDepartureMinute,
        arrivalGraceMinutes: _schedule?.isConfigured == true
            ? _schedule!.arrivalGraceMinutes
            : null,
      ),
    );
  }

  Future<bool> correctRecord({
    required TeacherAttendanceRecord record,
    required DateTime arrivedAt,
    required DateTime? departedAt,
    required String? notes,
  }) async {
    if (_isSaving) return false;
    final corrected = TeacherAttendanceRecord(
      id: record.id,
      schoolId: record.schoolId,
      attendanceDate: record.attendanceDate,
      arrivedAt: arrivedAt,
      departedAt: departedAt,
      notes: notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      correctedAt: DateTime.now(),
      expectedArrivalMinute: record.expectedArrivalMinute,
      expectedDepartureMinute: record.expectedDepartureMinute,
      arrivalGraceMinutes: record.arrivalGraceMinutes,
    );
    return _save(corrected);
  }

  Future<bool> _save(TeacherAttendanceRecord record) async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.save(record);
      final schoolId = _schoolId;
      if (schoolId != null) {
        _records = await _repository.listForSchool(schoolId);
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

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  bool _isBeforeToday(DateTime date) => date.isBefore(_today());

  String _recordId(String schoolId, DateTime date) =>
      'teacher-attendance:$schoolId:'
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
