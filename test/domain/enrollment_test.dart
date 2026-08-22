import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enrollment keeps inclusive historical membership dates', () {
    final enrollment = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: 'group-1',
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 9),
      endsOn: DateTime(2026, 12, 31),
    );

    expect(enrollment.isActiveOn(DateTime(2026, 8, 31)), isFalse);
    expect(enrollment.isActiveOn(DateTime(2026, 9)), isTrue);
    expect(enrollment.isActiveOn(DateTime(2026, 12, 31)), isTrue);
    expect(enrollment.isActiveOn(DateTime(2027)), isFalse);
  });

  test('enrollment rejects an end date before its start date', () {
    expect(
      () => Enrollment(
        id: 'enrollment-1',
        studentId: 'student-1',
        groupId: 'group-1',
        grade: PrimaryGrade.first,
        startsOn: DateTime(2026, 9),
        endsOn: DateTime(2026, 8, 31),
      ),
      throwsArgumentError,
    );
  });

  test('enrollment periods overlap on shared inclusive boundary dates', () {
    final first = Enrollment(
      id: 'enrollment-1',
      studentId: 'student-1',
      groupId: 'group-1',
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 9),
      endsOn: DateTime(2026, 10),
    );
    final second = Enrollment(
      id: 'enrollment-2',
      studentId: 'student-1',
      groupId: 'group-2',
      grade: PrimaryGrade.first,
      startsOn: DateTime(2026, 10),
    );

    expect(first.overlaps(second), isTrue);
  });
}
