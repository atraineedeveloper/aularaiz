import 'package:aularaiz/application/attendance/build_daily_attendance.dart';
import 'package:aularaiz/application/contracts/activity_repository.dart';
import 'package:aularaiz/application/contracts/attendance_repository.dart';
import 'package:aularaiz/application/contracts/enrollment_repository.dart';
import 'package:aularaiz/application/contracts/project_repository.dart';
import 'package:aularaiz/application/contracts/school_setup_repository.dart';
import 'package:aularaiz/application/contracts/school_year_repository.dart';
import 'package:aularaiz/application/contracts/student_enrollment_writer.dart';
import 'package:aularaiz/application/contracts/student_repository.dart';
import 'package:aularaiz/application/contracts/teaching_group_repository.dart';
import 'package:aularaiz/application/enrollment/enroll_student.dart';
import 'package:aularaiz/application/group/create_teaching_group.dart';
import 'package:aularaiz/application/project/create_activity.dart';
import 'package:aularaiz/application/project/create_project.dart';
import 'package:aularaiz/application/school_setup/create_initial_school_setup.dart';
import 'package:aularaiz/application/student/create_student_in_group.dart';
import 'package:aularaiz/application/student/reactivate_student_in_group.dart';
import 'package:aularaiz/core/id/id_generator.dart';
import 'package:aularaiz/core/id/uuid_id_generator.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/data/repositories/drift_activity_repository.dart';
import 'package:aularaiz/data/repositories/drift_attendance_repository.dart';
import 'package:aularaiz/data/repositories/drift_enrollment_repository.dart';
import 'package:aularaiz/data/repositories/drift_project_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_setup_repository.dart';
import 'package:aularaiz/data/repositories/drift_school_year_repository.dart';
import 'package:aularaiz/data/repositories/drift_student_enrollment_writer.dart';
import 'package:aularaiz/data/repositories/drift_student_repository.dart';
import 'package:aularaiz/data/repositories/drift_teaching_group_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class AppDependencies extends StatelessWidget {
  const AppDependencies({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>(
          create: (_) => AppDatabase.production(),
          dispose: (_, database) => database.close(),
        ),
        Provider<IdGenerator>(create: (_) => UuidIdGenerator()),
        Provider<SchoolSetupRepository>(
          create: (context) =>
              DriftSchoolSetupRepository(context.read<AppDatabase>()),
        ),
        Provider<SchoolYearRepository>(
          create: (context) =>
              DriftSchoolYearRepository(context.read<AppDatabase>()),
        ),
        Provider<TeachingGroupRepository>(
          create: (context) =>
              DriftTeachingGroupRepository(context.read<AppDatabase>()),
        ),
        Provider<StudentRepository>(
          create: (context) =>
              DriftStudentRepository(context.read<AppDatabase>()),
        ),
        Provider<EnrollmentRepository>(
          create: (context) =>
              DriftEnrollmentRepository(context.read<AppDatabase>()),
        ),
        Provider<AttendanceRepository>(
          create: (context) =>
              DriftAttendanceRepository(context.read<AppDatabase>()),
        ),
        Provider<ProjectRepository>(
          create: (context) =>
              DriftProjectRepository(context.read<AppDatabase>()),
        ),
        Provider<ActivityRepository>(
          create: (context) =>
              DriftActivityRepository(context.read<AppDatabase>()),
        ),
        Provider<StudentEnrollmentWriter>(
          create: (context) =>
              DriftStudentEnrollmentWriter(context.read<AppDatabase>()),
        ),
        Provider<CreateInitialSchoolSetup>(
          create: (context) => CreateInitialSchoolSetup(
            repository: context.read<SchoolSetupRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<CreateTeachingGroup>(
          create: (context) => CreateTeachingGroup(
            repository: context.read<TeachingGroupRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<EnrollStudent>(
          create: (context) => EnrollStudent(
            enrollmentRepository: context.read<EnrollmentRepository>(),
            schoolYearRepository: context.read<SchoolYearRepository>(),
            studentRepository: context.read<StudentRepository>(),
            teachingGroupRepository: context.read<TeachingGroupRepository>(),
          ),
        ),
        Provider<CreateStudentInGroup>(
          create: (context) => CreateStudentInGroup(
            teachingGroupRepository: context.read<TeachingGroupRepository>(),
            schoolYearRepository: context.read<SchoolYearRepository>(),
            enrollmentRepository: context.read<EnrollmentRepository>(),
            writer: context.read<StudentEnrollmentWriter>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<ReactivateStudentInGroup>(
          create: (context) => ReactivateStudentInGroup(
            enrollStudent: context.read<EnrollStudent>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<BuildDailyAttendance>(
          create: (context) => BuildDailyAttendance(
            attendanceRepository: context.read<AttendanceRepository>(),
            enrollmentRepository: context.read<EnrollmentRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<CreateProject>(
          create: (context) => CreateProject(
            repository: context.read<ProjectRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
        Provider<CreateActivity>(
          create: (context) => CreateActivity(
            activityRepository: context.read<ActivityRepository>(),
            projectRepository: context.read<ProjectRepository>(),
            enrollmentRepository: context.read<EnrollmentRepository>(),
            idGenerator: context.read<IdGenerator>(),
          ),
        ),
      ],
      child: child,
    );
  }
}
