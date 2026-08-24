import 'package:aularaiz/features/attendance/presentation/attendance_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthlyAttendanceSummary', () {
    test('counts present and late as attended', () {
      const summary = MonthlyAttendanceSummary(
        recorded: 5,
        present: 2,
        absent: 1,
        late: 1,
        justified: 1,
      );

      expect(summary.attended, 3);
      expect(summary.rate, 0.6);
    });

    test('does not invent a rate without recorded attendance', () {
      const summary = MonthlyAttendanceSummary(
        recorded: 0,
        present: 0,
        absent: 0,
        late: 0,
        justified: 0,
      );

      expect(summary.rate, isNull);
    });
  });
}
