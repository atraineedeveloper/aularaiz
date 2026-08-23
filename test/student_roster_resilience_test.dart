import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_enrollment_writer.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_year.dart';
import 'package:aularaiz/domain/school/teaching_group.dart';
import 'package:aularaiz/domain/student/enrollment.dart';
import 'package:aularaiz/domain/student/student.dart';
import 'package:aularaiz/features/student_roster/presentation/student_roster_controller.dart';
import 'package:aularaiz/features/student_roster/presentation/student_roster_screen.dart';
import 'package:aularaiz/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('roster supports 200 percent text and a long student name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = _RosterFixture();

    await tester.pumpWidget(
      fixture.app(textScaler: TextScaler.linear(2)),
    );
    await tester.pumpAndSettle();

    expect(find.text(fixture.student.displayName), findsOneWidget);
    expect(find.text('Alumnos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed roster load offers retry and recovers', (tester) async {
    final fixture = _RosterFixture(failuresBeforeSuccess: 1);

    await tester.pumpWidget(fixture.app());
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar la lista de alumnos.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('No se pudo guardar el alumno o la matrícula.'), findsNothing);
    expect(fixture.enrollmentRepository.findByGroupCalls, 1);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(fixture.enrollmentRepository.findByGroupCalls, 2);
    expect(find.text('No se pudo cargar la lista de alumnos.'), findsNothing);
    expect(find.text(fixture.student.displayName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final class _RosterFixture {
  _RosterFixture({int failuresBeforeSuccess = 0})
    : group = TeachingGroup(
        id: 'group-1',
        schoolId: 'school-1',
        schoolYearId: 'year-1',
        name: 'Grupo 1.º A con un nombre suficientemente largo',
        grades: {PrimaryGrade.first},
      ),
      student = Student(
        id: 'student-1',
        givenNames: 'María Fernanda de los Ángeles Guadalupe',
        firstSurname: 'Hernández Rodríguez',
        secondSurname: 'de la Cruz',
      ),
      enrollmentRepository = _MemoryEnrollmentRepository(
        failuresBeforeSuccess: failuresBeforeSuccess,
      ),
      studentRepository = _MemoryStudentRepository() {
    final enrollment = Enrollment(
      id: 'enrollment-1',
      studentId: student.id,
      groupId: group.id,
      grade: PrimaryGrade.first,
      listNumber: 38,
      startsOn: DateTime(2026, 9, 1),
    );
    enrollmentRepository.enrollments.add(enrollment);
    studentRepository.students[student.id] = student;

    final groupRepository = _MemoryTeachingGroupRepository(group);
    final schoolYearRepository = _MemorySchoolYearRepository();
    final ids = _TestIdGenerator();
    final createStudentInGroup = CreateStudentInGroup(
      teachingGroupRepository: groupRepository,
      schoolYearRepository: schoolYearRepository,
      enrollmentRepository: enrollmentRepository,
      writer: _MemoryStudentEnrollmentWriter(),
      idGenerator: ids,
    );
    final enrollStudent = EnrollStudent(
      enrollmentRepository: enrollmentRepository,
      schoolYearRepository: schoolYearRepository,
      studentRepository: studentRepository,
      teachingGroupRepository: groupRepository,
    );
    controller = StudentRosterController(
      studentRepository: studentRepository,
      enrollmentRepository: enrollmentRepository,
      createStudentInGroup: createStudentInGroup,
      reactivateStudentInGroup: ReactivateStudentInGroup(
        enrollStudent: enrollStudent,
        idGenerator: ids,
      ),
    );
  }

  final TeachingGroup group;
  final Student student;
  final _MemoryEnrollmentRepository enrollmentRepository;
  final _MemoryStudentRepository studentRepository;
  late final StudentRosterController controller;

  Widget app({TextScaler? textScaler}) {
    return ChangeNotifierProvider<StudentRosterController>.value(
      value: controller,
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: textScaler == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: StudentRosterScreen(group: group),
      ),
    );
  }
}

final class _MemoryEnrollmentRepository implements EnrollmentRepository {
  _MemoryEnrollmentRepository({required int failuresBeforeSuccess})
    : _failuresRemaining = failuresBeforeSuccess;

  final List<Enrollment> enrollments = [];
  int _failuresRemaining;
  int findByGroupCalls = 0;

  @override
  Future<List<Enrollment>> findByGroupId(String groupId) async {
    findByGroupCalls += 1;
    if (_failuresRemaining > 0) {
      _failuresRemaining -= 1;
      throw StateError('Synthetic roster load failure.');
    }
    return enrollments
        .where((enrollment) => enrollment.groupId == groupId)
        .toList(growable: false);
  }

  @override
  Future<List<Enrollment>> findByStudentId(String studentId) async {
    return enrollments
        .where((enrollment) => enrollment.studentId == studentId)
        .toList(growable: false);
  }

  @override
  Future<void> save(Enrollment enrollment) async {
    final index = enrollments.indexWhere((item) => item.id == enrollment.id);
    if (index < 0) {
      enrollments.add(enrollment);
    } else {
      enrollments[index] = enrollment;
    }
  }
}

final class _MemoryStudentRepository implements StudentRepository {
  final Map<String, Student> students = {};

  @override
  Future<Student?> findById(String id) async => students[id];

  @override
  Future<List<Student>> listAll() async => students.values.toList();

  @override
  Future<void> save(Student student) async {
    students[student.id] = student;
  }
}

final class _MemoryTeachingGroupRepository implements TeachingGroupRepository {
  _MemoryTeachingGroupRepository(this.group);

  final TeachingGroup group;

  @override
  Future<TeachingGroup?> findById(String id) async => id == group.id ? group : null;

  @override
  Future<List<TeachingGroup>> listForSchoolYear(String schoolYearId) async {
    return group.schoolYearId == schoolYearId ? [group] : const [];
  }

  @override
  Future<void> save(TeachingGroup group) async {}
}

final class _MemorySchoolYearRepository implements SchoolYearRepository {
  @override
  Future<SchoolYear?> findById(String id) async => null;
}

final class _MemoryStudentEnrollmentWriter implements StudentEnrollmentWriter {
  @override
  Future<void> saveNewStudentWithEnrollment({
    required Student student,
    required Enrollment enrollment,
  }) async {}
}

final class _TestIdGenerator implements IdGenerator {
  int _next = 0;

  @override
  String newId() {
    _next += 1;
    return 'test-$_next';
  }
}
