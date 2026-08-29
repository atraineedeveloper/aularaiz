import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/evaluation_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/core/logging/safe_log.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:aularaiz/domain/evaluation/achievement_level.dart';
import 'package:aularaiz/domain/evaluation/delivery_status.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:flutter/foundation.dart';

final class DashboardStudentRisk {
  const DashboardStudentRisk({
    required this.studentId,
    required this.name,
    required this.attendanceRate,
    required this.recordedDays,
  });

  final String studentId;
  final String name;
  final double attendanceRate;
  final int recordedDays;
}

final class GroupDashboardController extends ChangeNotifier {
  GroupDashboardController({
    required EnrollmentRepository enrollmentRepository,
    required StudentRepository studentRepository,
    required AttendanceRepository attendanceRepository,
    required ProjectRepository projectRepository,
    required ActivityRepository activityRepository,
    required EvaluationRepository evaluationRepository,
  }) : _enrollmentRepository = enrollmentRepository,
       _studentRepository = studentRepository,
       _attendanceRepository = attendanceRepository,
       _projectRepository = projectRepository,
       _activityRepository = activityRepository,
       _evaluationRepository = evaluationRepository;

  final EnrollmentRepository _enrollmentRepository;
  final StudentRepository _studentRepository;
  final AttendanceRepository _attendanceRepository;
  final ProjectRepository _projectRepository;
  final ActivityRepository _activityRepository;
  final EvaluationRepository _evaluationRepository;

  TeachingGroup? _group;
  bool _isLoading = false;
  Object? _error;
  int _studentCount = 0;
  int _projectCount = 0;
  int _activityCount = 0;
  double? _attendanceRate;
  DateTime? _attendanceMonth;
  int _recordedAttendanceDays = 0;
  double? _deliveryRate;
  int _deliveryDecisions = 0;
  Map<AchievementLevel, int> _achievementCounts = const {};
  List<DashboardStudentRisk> _attendanceRisks = const [];

  bool get isLoading => _isLoading;
  Object? get error => _error;
  int get studentCount => _studentCount;
  int get projectCount => _projectCount;
  int get activityCount => _activityCount;
  double? get attendanceRate => _attendanceRate;
  DateTime? get attendanceMonth => _attendanceMonth;
  int get recordedAttendanceDays => _recordedAttendanceDays;
  double? get deliveryRate => _deliveryRate;
  int get deliveryDecisions => _deliveryDecisions;
  Map<AchievementLevel, int> get achievementCounts => _achievementCounts;
  List<DashboardStudentRisk> get attendanceRisks => _attendanceRisks;

  int get evaluatedCount =>
      _achievementCounts.values.fold<int>(0, (sum, value) => sum + value);

  Future<void> load(TeachingGroup group) async {
    _group = group;
    await refresh();
  }

  Future<void> refresh() async {
    final group = _group;
    if (group == null || _isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final enrollments = await _enrollmentRepository.findByGroupId(group.id);
      final studentIds = enrollments.map((item) => item.studentId).toSet();
      _studentCount = studentIds.length;

      final projects = await _projectRepository.listForGroup(group.id);
      _projectCount = projects.length;
      final activities = <String>[];
      for (final project in projects) {
        final rows = await _activityRepository.listForProject(project.id);
        activities.addAll(rows.map((item) => item.id));
      }
      _activityCount = activities.length;

      var delivered = 0;
      var notDelivered = 0;
      final achievementCounts = <AchievementLevel, int>{
        for (final level in AchievementLevel.values) level: 0,
      };
      for (final activityId in activities) {
        final evaluations = await _evaluationRepository.listForActivity(
          activityId,
        );
        for (final evaluation in evaluations) {
          switch (evaluation.deliveryStatus) {
            case DeliveryStatus.pending:
              break;
            case DeliveryStatus.delivered:
              delivered += 1;
            case DeliveryStatus.notDelivered:
              notDelivered += 1;
          }
          final achievement = evaluation.achievement;
          if (achievement != null) {
            achievementCounts[achievement] =
                (achievementCounts[achievement] ?? 0) + 1;
          }
        }
      }
      _deliveryDecisions = delivered + notDelivered;
      _deliveryRate = _deliveryDecisions == 0
          ? null
          : delivered / _deliveryDecisions;
      _achievementCounts = Map.unmodifiable(achievementCounts);

      final attendance = await _latestAttendance(group.id);
      if (attendance == null) {
        _attendanceRate = null;
        _attendanceMonth = null;
        _recordedAttendanceDays = 0;
        _attendanceRisks = const [];
      } else {
        _attendanceMonth = attendance.month;
        _recordedAttendanceDays = attendance.days.length;
        await _calculateAttendance(attendance.days, studentIds);
      }
    } catch (error) {
      _error = error;
      SafeLog.operationFailure('load_group_dashboard', error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<({DateTime month, List<DailyAttendance> days})?> _latestAttendance(
    String groupId,
  ) async {
    final now = DateTime.now();
    for (var offset = 0; offset < 12; offset++) {
      final month = DateTime(now.year, now.month - offset);
      final days = await _attendanceRepository.listForMonth(groupId, month);
      if (days.isNotEmpty) return (month: month, days: days);
    }
    return null;
  }

  Future<void> _calculateAttendance(
    List<DailyAttendance> days,
    Set<String> enrolledStudentIds,
  ) async {
    var recorded = 0;
    var attended = 0;
    final perStudent = <String, ({int recorded, int attended})>{};

    for (final day in days) {
      for (final entry in day.entries.values) {
        if (!enrolledStudentIds.contains(entry.studentId)) continue;
        final countsAsAttended =
            entry.status == AttendanceStatus.present ||
            entry.status == AttendanceStatus.late;
        recorded += 1;
        if (countsAsAttended) attended += 1;
        final current =
            perStudent[entry.studentId] ?? (recorded: 0, attended: 0);
        perStudent[entry.studentId] = (
          recorded: current.recorded + 1,
          attended: current.attended + (countsAsAttended ? 1 : 0),
        );
      }
    }
    _attendanceRate = recorded == 0 ? null : attended / recorded;

    final risks = <DashboardStudentRisk>[];
    for (final entry in perStudent.entries) {
      if (entry.value.recorded < 3) continue;
      final rate = entry.value.attended / entry.value.recorded;
      if (rate >= 0.8) continue;
      final student = await _studentRepository.findById(entry.key);
      if (student == null) continue;
      risks.add(
        DashboardStudentRisk(
          studentId: entry.key,
          name: student.displayName,
          attendanceRate: rate,
          recordedDays: entry.value.recorded,
        ),
      );
    }
    risks.sort((left, right) {
      final byRate = left.attendanceRate.compareTo(right.attendanceRate);
      return byRate != 0 ? byRate : left.name.compareTo(right.name);
    });
    _attendanceRisks = List.unmodifiable(risks.take(6));
  }
}
