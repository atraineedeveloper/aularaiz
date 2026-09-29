import 'package:aularaiz/domain/teacher/teacher_attendance_record.dart';
import 'package:aularaiz/domain/teacher/teacher_attendance_schedule.dart';

abstract interface class TeacherAttendanceRepository {
  Future<List<TeacherAttendanceRecord>> listForSchool(String schoolId);

  Future<TeacherAttendanceRecord?> findForDate(String schoolId, DateTime date);

  Future<void> save(TeacherAttendanceRecord record);

  Future<TeacherAttendanceSchedule> loadSchedule(String schoolId);

  Future<void> saveSchedule(TeacherAttendanceSchedule schedule);
}
