import 'dart:io';

import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_enrollment_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_year_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_enrollment_writer.dart';
import 'package:aularaiz/data/repositories/drift_student_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Phase 3 setup, group and roster survive a database reopen', () async {
    final directory = await Directory.systemTemp.createTemp('aularaiz-phase3-');
    final file = File('${directory.path}${Platform.pathSeparator}phase3.sqlite');

    try {
      final ids = _SequenceIdGenerator();
      var database = AppDatabase.forTesting(NativeDatabase(file));
      var setupRepository = DriftSchoolSetupRepository(database);
      var groupRepository = DriftTeachingGroupRepository(database);
      var schoolYearRepository = DriftSchoolYearRepository(database);
      var enrollmentRepository = DriftEnrollmentRepository(database);
      var studentRepository = DriftStudentRepository(database);

      await CreateInitialSchoolSetup(
        repository: setupRepository,
        idGenerator: ids,
      )(
        schoolName: 'Escuela Alpha',
        organization: SchoolOrganization.complete,
        state: 'Entidad Demo',
        municipality: 'Municipio Demo',
        locality: 'Localidad Demo',
        schoolYearLabel: '2026-2027',
        startsOn: DateTime(2026, 8, 31),
        endsOn: DateTime(2027, 7, 15),
      );

      final setup = await setupRepository.loadInitialSetup();
      expect(setup, isNotNull);

      final group = await CreateTeachingGroup(
        repository: groupRepository,
        idGenerator: ids,
      )(
        schoolId: setup!.school.id,
        schoolYearId: setup.schoolYear.id,
        name: '1.º y 2.º A',
        grades: <PrimaryGrade>{PrimaryGrade.first, PrimaryGrade.second},
        shift: 'Matutino',
      );

      final createStudent = CreateStudentInGroup(
        teachingGroupRepository: groupRepository,
        schoolYearRepository: schoolYearRepository,
        enrollmentRepository: enrollmentRepository,
        writer: DriftStudentEnrollmentWriter(database),
        idGenerator: ids,
      );
      final studentResult = await createStudent(
        groupId: group.id,
        givenNames: 'Alumno',
        firstSurname: 'Ejemplo',
        grade: PrimaryGrade.first,
        listNumber: 1,
      );
      expect(studentResult, isA<CreateStudentInGroupSucceeded>());

      await database.close();

      database = AppDatabase.forTesting(NativeDatabase(file));
      setupRepository = DriftSchoolSetupRepository(database);
      groupRepository = DriftTeachingGroupRepository(database);
      schoolYearRepository = DriftSchoolYearRepository(database);
      enrollmentRepository = DriftEnrollmentRepository(database);
      studentRepository = DriftStudentRepository(database);

      final reopenedSetup = await setupRepository.loadInitialSetup();
      final reopenedGroups = await groupRepository.listForSchoolYear(
        reopenedSetup!.schoolYear.id,
      );
      final reopenedEnrollments = await enrollmentRepository.findByGroupId(
        reopenedGroups.single.id,
      );
      final reopenedStudent = await studentRepository.findById(
        reopenedEnrollments.single.studentId,
      );

      expect(reopenedSetup.school.name, 'Escuela Alpha');
      expect(reopenedGroups.single.isMultigrade, isTrue);
      expect(reopenedGroups.single.shift, 'Matutino');
      expect(reopenedEnrollments.single.listNumber, 1);
      expect(reopenedStudent?.displayName, 'Alumno Ejemplo');

      await database.close();
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}

final class _SequenceIdGenerator implements IdGenerator {
  int _value = 0;

  @override
  String newId() {
    _value += 1;
    return 'phase3-$_value';
  }
}
