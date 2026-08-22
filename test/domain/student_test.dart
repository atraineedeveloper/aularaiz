import 'package:aularaiz/domain/student/student.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('birth date is optional and age is derived for a reference date', () {
    final student = Student(
      id: 'student-1',
      givenNames: 'Ana',
      firstSurname: 'Pérez',
      birthDate: DateTime(2018, 9, 15, 14),
    );

    expect(student.birthDate, DateTime(2018, 9, 15));
    expect(student.ageOn(DateTime(2026, 9, 14)), 7);
    expect(student.ageOn(DateTime(2026, 9, 15)), 8);
  });

  test('age is undefined when birth date is absent or in the future', () {
    final withoutBirthDate = Student(
      id: 'student-1',
      givenNames: 'Ana',
      firstSurname: 'Pérez',
    );
    final futureBirthDate = Student(
      id: 'student-2',
      givenNames: 'Luis',
      firstSurname: 'López',
      birthDate: DateTime(2030, 1, 1),
    );

    expect(withoutBirthDate.ageOn(DateTime(2026, 9, 1)), isNull);
    expect(futureBirthDate.ageOn(DateTime(2026, 9, 1)), isNull);
  });
}
