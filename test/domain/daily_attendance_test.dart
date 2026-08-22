import 'package:aularaiz/domain/attendance/attendance_entry.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/attendance/daily_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily attendance exposes the four required semantic states', () {
    expect(AttendanceStatus.values, <AttendanceStatus>[
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.late,
      AttendanceStatus.justifiedAbsence,
    ]);
  });

  test('daily attendance preserves an explicit historical roster', () {
    final attendance = DailyAttendance(
      id: 'attendance-1',
      groupId: 'group-1',
      date: DateTime(2026, 9, 1, 12, 30),
      entries: <AttendanceEntry>[
        AttendanceEntry(
          studentId: 'student-1',
          status: AttendanceStatus.present,
        ),
        AttendanceEntry(
          studentId: 'student-2',
          status: AttendanceStatus.absent,
        ),
      ],
    );

    expect(attendance.date, DateTime(2026, 9, 1));
    expect(attendance.entries.keys, <String>{'student-1', 'student-2'});
    expect(attendance.count(AttendanceStatus.present), 1);
    expect(attendance.count(AttendanceStatus.absent), 1);
  });

  test('changing a status cannot add a student outside the saved roster', () {
    final attendance = DailyAttendance(
      id: 'attendance-1',
      groupId: 'group-1',
      date: DateTime(2026, 9, 1),
      entries: <AttendanceEntry>[
        AttendanceEntry(
          studentId: 'student-1',
          status: AttendanceStatus.present,
        ),
      ],
    );

    final updated = attendance.withStatus(
      'student-1',
      AttendanceStatus.justifiedAbsence,
    );

    expect(updated.statusFor('student-1'), AttendanceStatus.justifiedAbsence);
    expect(
      () => attendance.withStatus('student-2', AttendanceStatus.present),
      throwsArgumentError,
    );
  });

  test('duplicate students are rejected from a daily roster', () {
    expect(
      () => DailyAttendance(
        id: 'attendance-1',
        groupId: 'group-1',
        date: DateTime(2026, 9, 1),
        entries: <AttendanceEntry>[
          AttendanceEntry(
            studentId: 'student-1',
            status: AttendanceStatus.present,
          ),
          AttendanceEntry(
            studentId: 'student-1',
            status: AttendanceStatus.absent,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
