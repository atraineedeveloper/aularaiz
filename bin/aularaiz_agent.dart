import 'dart:convert';
import 'dart:io';

import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/data/local/app_database.dart';
import 'package:aularaiz/domain/attendance/attendance_status.dart';
import 'package:aularaiz/domain/education/primary_grade.dart';
import 'package:aularaiz/domain/project/formative_field.dart';
import 'package:aularaiz/domain/project/project_methodology.dart';
import 'package:aularaiz/domain/school/school_leadership_role.dart';
import 'package:aularaiz/domain/school/school_organization.dart';
import 'package:aularaiz/domain/student/student_sex.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:aularaiz/domain/teacher/teaching_role.dart';
import 'package:aularaiz/infrastructure/automation/agent_invocation.dart';
import 'package:aularaiz/infrastructure/automation/automation_runtime.dart';

Future<void> main(List<String> arguments) async {
  var pretty = arguments.contains('--pretty');
  try {
    final invocation = AgentInvocation.parse(arguments);
    pretty = invocation.pretty;

    if (invocation.help || invocation.command == null) {
      _writeJson(_helpEnvelope(), pretty: pretty);
      exitCode = 0;
      return;
    }

    final databaseFile = await AutomationDatabaseLocator.findExisting(
      profile: invocation.profile,
      explicitPath: invocation.databasePath,
    );

    if (invocation.command == 'status' && databaseFile == null) {
      _writeJson(
        AutomationEnvelope(
          kind: 'status',
          privacy: const AutomationPrivacy(),
          data: <String, Object?>{
            'database': <String, Object?>{
              'exists': false,
              'profile': invocation.profile.name,
              'discovery': invocation.databasePath == null
                  ? 'automatic'
                  : 'explicit',
            },
            'configured': false,
            'capabilities': AutomationCapabilityCatalog.capabilities,
          },
        ).toJson(),
        pretty: pretty,
      );
      exitCode = 0;
      return;
    }

    if (databaseFile == null) {
      throw const AgentCliFailure(
        'database-not-found',
        'No se encontró la base local de AulaRaíz. Usa --database <ruta> para indicar su ubicación.',
        3,
      );
    }

    final runtime = await AutomationRuntime.open(
      databaseFile: databaseFile,
      profile: invocation.profile,
    );
    try {
      final privacy = AutomationPrivacy(
        includePersonalData: invocation.includePersonalData,
      );
      final envelope = switch (invocation.command) {
        'status' => await runtime.service.status(privacy: privacy),
        'schools' => await runtime.service.listSchools(privacy: privacy),
        'groups' => await runtime.service.listGroups(),
        'projects' => await runtime.service.listProjects(
          groupId: invocation.requireOption('group'),
        ),
        'activities' => await runtime.service.listActivities(
          projectId: invocation.requireOption('project'),
        ),
        'students' => await runtime.service.listStudents(
          groupId: invocation.requireOption('group'),
          privacy: privacy,
        ),
        'group-summary' => await runtime.service.groupSummary(
          groupId: invocation.requireOption('group'),
          referenceMonth: _parseMonth(invocation.requireOption('month')),
          privacy: privacy,
        ),
        'recommend' => await runtime.service.recommendations(
          groupId: invocation.requireOption('group'),
          referenceMonth: _parseMonth(invocation.requireOption('month')),
          privacy: privacy,
        ),
        'workspace-create' => await runtime.mutations.createWorkspace(
          schoolName: invocation.requireOption('school-name'),
          cct: invocation.options['cct'],
          organization: _parseOrganization(
            invocation.options['organization'] ?? 'unspecified',
          ),
          state: invocation.options['state'],
          municipality: invocation.options['municipality'],
          locality: invocation.options['locality'],
          schoolZone: invocation.options['school-zone'],
          schoolSector: invocation.options['school-sector'],
          supervisorName: invocation.options['supervisor-name'],
          leadershipName: invocation.options['leadership-name'],
          leadershipRole: _parseLeadershipRole(
            invocation.options['leadership-role'],
          ),
          schoolYearLabel: invocation.requireOption('school-year'),
          startsOn: _parseDate(invocation.requireOption('starts-on')),
          endsOn: _parseDate(invocation.requireOption('ends-on')),
          groupName: invocation.requireOption('group-name'),
          grades: _parseGrades(invocation.requireOption('grades')),
          shift: invocation.options['shift'],
          teachingRole: _parseTeachingRole(invocation.options['teaching-role']),
          teacherName: invocation.options['teacher-name'],
          apply: invocation.apply,
          privacy: privacy,
        ),
        'school-update' => await runtime.mutations.updateSchool(
          schoolId: invocation.requireOption('school'),
          name: invocation.requireOption('school-name'),
          cct: invocation.options['cct'],
          state: invocation.options['state'],
          municipality: invocation.options['municipality'],
          locality: invocation.options['locality'],
          schoolZone: invocation.options['school-zone'],
          schoolSector: invocation.options['school-sector'],
          supervisorName: invocation.options['supervisor-name'],
          leadershipName: invocation.options['leadership-name'],
          leadershipRole: _parseLeadershipRole(
            invocation.options['leadership-role'],
          ),
          apply: invocation.apply,
        ),
        'school-delete' => await runtime.mutations.deleteSchool(
          schoolId: invocation.requireOption('school'),
          apply: invocation.apply,
        ),
        'group-create' => await runtime.mutations.createGroup(
          schoolId: invocation.requireOption('school'),
          schoolYearId: invocation.requireOption('school-year-id'),
          name: invocation.requireOption('group-name'),
          grades: _parseGrades(invocation.requireOption('grades')),
          shift: invocation.options['shift'],
          teachingRole: _parseTeachingRole(invocation.options['teaching-role']),
          apply: invocation.apply,
        ),
        'group-update' => await runtime.mutations.updateGroup(
          groupId: invocation.requireOption('group'),
          name: invocation.requireOption('group-name'),
          grades: _parseGrades(invocation.requireOption('grades')),
          shift: invocation.options['shift'],
          teachingRole: _parseTeachingRole(invocation.options['teaching-role']),
          apply: invocation.apply,
        ),
        'group-delete' => await runtime.mutations.deleteGroup(
          groupId: invocation.requireOption('group'),
          apply: invocation.apply,
        ),
        'student-create' => await runtime.mutations.createStudent(
          groupId: invocation.requireOption('group'),
          givenNames: invocation.requireOption('given-names'),
          firstSurname: invocation.requireOption('first-surname'),
          secondSurname: invocation.options['second-surname'],
          sex: _parseSex(invocation.options['sex']),
          birthDate: invocation.options['birth-date'] == null
              ? null
              : _parseDate(invocation.options['birth-date']!),
          grade: _parseGrade(invocation.requireOption('grade')),
          listNumber: _parsePositiveInt(
            invocation.requireOption('list-number'),
            option: 'list-number',
          ),
          apply: invocation.apply,
          privacy: privacy,
        ),
        'student-update' => await runtime.mutations.updateStudent(
          studentId: invocation.requireOption('student'),
          givenNames: invocation.requireOption('given-names'),
          firstSurname: invocation.requireOption('first-surname'),
          secondSurname: invocation.options['second-surname'],
          sex: _parseSex(invocation.options['sex']),
          birthDate: invocation.options['birth-date'] == null
              ? null
              : _parseDate(invocation.options['birth-date']!),
          apply: invocation.apply,
          privacy: privacy,
        ),
        'project-create' => await runtime.mutations.createProject(
          groupId: invocation.requireOption('group'),
          title: invocation.requireOption('title'),
          methodology: _parseMethodology(
            invocation.options['methodology'] ?? 'unspecified',
          ),
          grades: _parseGrades(invocation.requireOption('grades')),
          apply: invocation.apply,
        ),
        'project-update' => await runtime.mutations.updateProject(
          projectId: invocation.requireOption('project'),
          title: invocation.requireOption('title'),
          methodology: _parseMethodology(
            invocation.options['methodology'] ?? 'unspecified',
          ),
          grades: _parseGrades(invocation.requireOption('grades')),
          apply: invocation.apply,
        ),
        'activity-create' => await runtime.mutations.createActivity(
          projectId: invocation.requireOption('project'),
          title: invocation.requireOption('title'),
          formativeField: _parseFormativeField(
            invocation.requireOption('formative-field'),
          ),
          grades: _parseGrades(invocation.requireOption('grades')),
          occursOn: _parseDate(invocation.requireOption('date')),
          apply: invocation.apply,
        ),
        'activity-delete' => await runtime.mutations.deleteActivity(
          activityId: invocation.requireOption('activity'),
          apply: invocation.apply,
        ),
        'database-diagnose' => await _diagnoseDatabase(runtime),
        'student-note' => await runtime.service.studentNote(
          studentId: invocation.requireOption('student'),
          kind: _parseEntryKind(invocation.requireOption('kind')),
          occurredAt: _parseDate(
            invocation.options['date'] ?? _todayLabel(DateTime.now()),
          ),
          text: await _resolveNoteText(invocation),
          apply: invocation.apply,
          privacy: privacy,
        ),
        'attendance-set' => await runtime.mutations.setAttendance(
          groupId: invocation.requireOption('group'),
          studentId: invocation.requireOption('student'),
          date: _parseDate(invocation.requireOption('date')),
          status: _parseAttendanceStatus(invocation.requireOption('status')),
          apply: invocation.apply,
          privacy: privacy,
        ),
        'student-deactivate' => await runtime.mutations.deactivateStudent(
          groupId: invocation.requireOption('group'),
          studentId: invocation.requireOption('student'),
          endsOn: _parseDate(
            invocation.options['date'] ?? _todayLabel(DateTime.now()),
          ),
          apply: invocation.apply,
          privacy: privacy,
        ),
        'student-reactivate' => await runtime.mutations.reactivateStudent(
          groupId: invocation.requireOption('group'),
          studentId: invocation.requireOption('student'),
          grade: _parseGrade(invocation.requireOption('grade')),
          listNumber: _parsePositiveInt(
            invocation.requireOption('list-number'),
            option: 'list-number',
          ),
          startsOn: invocation.options['date'] == null
              ? null
              : _parseDate(invocation.options['date']!),
          apply: invocation.apply,
          privacy: privacy,
        ),
        _ => throw AgentUsageFailure(
          'Comando desconocido: ${invocation.command}',
        ),
      };

      final json = envelope.toJson();
      if (invocation.command == 'status') {
        final data = Map<String, Object?>.from(envelope.data);
        data['database'] = <String, Object?>{
          'exists': true,
          'profile': invocation.profile.name,
          'discovery': invocation.databasePath == null
              ? 'automatic'
              : 'explicit',
        };
        json['data'] = data;
      }
      _writeJson(json, pretty: pretty);
      exitCode = 0;
    } finally {
      await runtime.close();
    }
  } on AgentCliFailure catch (error) {
    _writeJson(_errorEnvelope(error.code, error.message), pretty: pretty);
    exitCode = error.exitCode;
  } on FormatException catch (error) {
    _writeJson(_errorEnvelope('invalid-input', error.message), pretty: pretty);
    exitCode = 2;
  } on ArgumentError catch (error) {
    _writeJson(
      _errorEnvelope(
        'invalid-input',
        '${error.message ?? 'Entrada inválida.'}',
      ),
      pretty: pretty,
    );
    exitCode = 2;
  } on StateError catch (error) {
    _writeJson(_errorEnvelope('data-state', error.message), pretty: pretty);
    exitCode = 4;
  } on FileSystemException {
    _writeJson(
      _errorEnvelope(
        'database-open-failed',
        'No se pudo abrir la base local de AulaRaíz.',
      ),
      pretty: pretty,
    );
    exitCode = 3;
  } catch (_) {
    _writeJson(
      _errorEnvelope(
        'automation-failed',
        'La operación de automatización no pudo completarse.',
      ),
      pretty: pretty,
    );
    exitCode = 1;
  }
}

Future<String> _resolveNoteText(AgentInvocation invocation) async {
  final inlineText = invocation.options['text'];
  if (inlineText != null && invocation.textFromStdin) {
    throw AgentUsageFailure('Usa --text o --text-stdin, pero no ambos.');
  }
  if (!invocation.textFromStdin) {
    return invocation.requireOption('text');
  }

  final text = await utf8.decoder.bind(stdin).join();
  if (text.trim().isEmpty) {
    throw AgentUsageFailure('--text-stdin no recibió contenido.');
  }
  return text;
}

Future<AutomationEnvelope> _diagnoseDatabase(AutomationRuntime runtime) async {
  final integrity = await runtime.database
      .customSelect('PRAGMA integrity_check')
      .get();
  final foreignKeys = await runtime.database
      .customSelect('PRAGMA foreign_key_check')
      .get();
  final version = await runtime.database
      .customSelect('PRAGMA user_version')
      .getSingle();
  return AutomationEnvelope(
    kind: 'database-diagnose',
    privacy: const AutomationPrivacy(),
    data: {
      'integrity': integrity.map((row) => row.data.values.first).toList(),
      'foreign_key_violation_count': foreignKeys.length,
      'user_version': version.read<int>('user_version'),
      'expected_version': AppDatabase.currentSchemaVersion,
    },
  );
}

DateTime _parseMonth(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw const FormatException('El mes debe tener formato YYYY-MM.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) {
    throw const FormatException('El mes debe estar entre 01 y 12.');
  }
  return DateTime(year, month);
}

DateTime _parseDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw const FormatException('La fecha debe tener formato YYYY-MM-DD.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final result = DateTime(year, month, day);
  if (result.year != year || result.month != month || result.day != day) {
    throw const FormatException('La fecha no es válida.');
  }
  return result;
}

AttendanceStatus _parseAttendanceStatus(String value) {
  return switch (value) {
    'present' => AttendanceStatus.present,
    'absent' => AttendanceStatus.absent,
    'late' => AttendanceStatus.late,
    'justified-absence' ||
    'justifiedAbsence' => AttendanceStatus.justifiedAbsence,
    _ => throw const FormatException(
      '--status debe ser present, absent, late o justified-absence.',
    ),
  };
}

PrimaryGrade _parseGrade(String value) {
  final number = int.tryParse(value);
  if (number == null) {
    throw const FormatException('--grade debe ser un número del 1 al 6.');
  }
  try {
    return PrimaryGrade.fromNumber(number);
  } on ArgumentError {
    throw const FormatException('--grade debe estar entre 1 y 6.');
  }
}

Set<PrimaryGrade> _parseGrades(String value) {
  final grades = value
      .split(',')
      .map((item) => int.tryParse(item.trim()))
      .whereType<int>()
      .map(PrimaryGrade.fromNumber)
      .toSet();
  if (grades.isEmpty) {
    throw AgentUsageFailure(
      '--grades debe contener grados 1..6 separados por coma.',
    );
  }
  return grades;
}

SchoolOrganization _parseOrganization(String value) {
  for (final organization in SchoolOrganization.values) {
    if (organization.name == value.trim()) return organization;
  }
  throw AgentUsageFailure(
    '--organization debe ser unspecified, unitary, twoTeacher, threeTeacher, fourTeacher, fiveTeacher o complete.',
  );
}

TeachingRole? _parseTeachingRole(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final role = TeachingRole.tryParse(value);
  if (role == null) {
    throw AgentUsageFailure(
      '--teaching-role debe ser teacher, teacherWithLeadership, principal o actingPrincipal.',
    );
  }
  return role;
}

SchoolLeadershipRole? _parseLeadershipRole(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final role = SchoolLeadershipRole.tryParse(value);
  if (role == null) {
    throw AgentUsageFailure(
      '--leadership-role debe ser principal, teacherWithLeadership o actingPrincipal.',
    );
  }
  return role;
}

StudentSex? _parseSex(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return switch (value.trim()) {
    'male' => StudentSex.male,
    'female' => StudentSex.female,
    _ => throw AgentUsageFailure('--sex debe ser male o female.'),
  };
}

ProjectMethodology _parseMethodology(String value) {
  for (final methodology in ProjectMethodology.values) {
    if (methodology.name == value.trim()) return methodology;
  }
  throw AgentUsageFailure('--methodology no corresponde al catálogo admitido.');
}

FormativeField _parseFormativeField(String value) {
  for (final field in FormativeField.values) {
    if (field.name == value.trim()) return field;
  }
  throw AgentUsageFailure(
    '--formative-field no corresponde al catálogo admitido.',
  );
}

int _parsePositiveInt(String value, {required String option}) {
  final number = int.tryParse(value);
  if (number == null || number <= 0) {
    throw FormatException('--$option debe ser un entero mayor que cero.');
  }
  return number;
}

StudentRecordEntryKind _parseEntryKind(String value) {
  return switch (value) {
    'observation' => StudentRecordEntryKind.observation,
    'family-agreement' ||
    'familyAgreement' => StudentRecordEntryKind.familyAgreement,
    _ => throw const FormatException(
      '--kind debe ser observation o family-agreement.',
    ),
  };
}

String _todayLabel(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

Map<String, Object?> _helpEnvelope() => <String, Object?>{
  'schema': AutomationEnvelope.schema,
  'kind': 'help',
  'privacy': const AutomationPrivacy().toJson(),
  'data': <String, Object?>{
    'usage': 'dart run bin/aularaiz_agent.dart <command> [options]',
    'commands': <Map<String, Object?>>[
      <String, Object?>{'name': 'status'},
      <String, Object?>{'name': 'schools'},
      <String, Object?>{'name': 'groups'},
      <String, Object?>{
        'name': 'projects',
        'required': <String>['--group'],
      },
      <String, Object?>{
        'name': 'activities',
        'required': <String>['--project'],
      },
      <String, Object?>{
        'name': 'students',
        'required': <String>['--group'],
        'optional': <String>['--include-personal-data'],
      },
      <String, Object?>{
        'name': 'workspace-create',
        'required': <String>[
          '--school-name',
          '--school-year',
          '--starts-on',
          '--ends-on',
          '--group-name',
          '--grades 1,2,...',
        ],
        'optional': <String>[
          '--cct',
          '--organization',
          '--state',
          '--municipality',
          '--locality',
          '--school-zone',
          '--school-sector',
          '--supervisor-name',
          '--leadership-name',
          '--leadership-role principal|teacherWithLeadership|actingPrincipal',
          '--shift',
          '--teaching-role teacher|teacherWithLeadership|principal|actingPrincipal',
          '--teacher-name',
        ],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'school-update',
        'required': <String>['--school', '--school-name'],
        'optional': <String>[
          '--cct',
          '--state',
          '--municipality',
          '--locality',
          '--school-zone',
          '--school-sector',
          '--supervisor-name',
          '--leadership-name',
          '--leadership-role principal|teacherWithLeadership|actingPrincipal',
        ],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'school-delete',
        'required': <String>['--school'],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'group-create',
        'required': <String>[
          '--school',
          '--school-year-id',
          '--group-name',
          '--grades 1,2,...',
        ],
        'optional': <String>[
          '--shift',
          '--teaching-role teacher|teacherWithLeadership|principal|actingPrincipal',
        ],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'group-update',
        'required': <String>['--group', '--group-name', '--grades 1,2,...'],
        'optional': <String>[
          '--shift',
          '--teaching-role teacher|teacherWithLeadership|principal|actingPrincipal',
        ],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'group-delete',
        'required': <String>['--group'],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'student-create',
        'required': <String>[
          '--group',
          '--given-names',
          '--first-surname',
          '--grade',
          '--list-number',
        ],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'student-update',
        'required': <String>['--student', '--given-names', '--first-surname'],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'project-create',
        'required': <String>['--group', '--title', '--grades'],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'project-update',
        'required': <String>['--project', '--title', '--grades'],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'activity-create',
        'required': <String>[
          '--project',
          '--title',
          '--formative-field',
          '--grades',
          '--date',
        ],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'activity-delete',
        'required': <String>['--activity'],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{'name': 'database-diagnose'},
      <String, Object?>{
        'name': 'group-summary',
        'required': <String>['--group', '--month YYYY-MM'],
      },
      <String, Object?>{
        'name': 'recommend',
        'required': <String>['--group', '--month YYYY-MM'],
      },
      <String, Object?>{
        'name': 'student-note',
        'required': <String>[
          '--student',
          '--kind',
          '--text <value> | --text-stdin',
        ],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'attendance-set',
        'required': <String>[
          '--group',
          '--student',
          '--date YYYY-MM-DD',
          '--status present|absent|late|justified-absence',
        ],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'student-deactivate',
        'required': <String>['--group', '--student'],
        'optional': <String>['--date YYYY-MM-DD'],
        'mutation': 'dry-run unless --apply is present',
      },
      <String, Object?>{
        'name': 'student-reactivate',
        'required': <String>[
          '--group',
          '--student',
          '--grade 1..6',
          '--list-number <n>',
        ],
        'optional': <String>['--date YYYY-MM-DD'],
        'mutation': 'dry-run unless --apply is present',
      },
    ],
    'global_options': <String>[
      '--database <path>',
      '--profile production|demo',
      '--apply',
      '--include-personal-data',
      '--confirm-delete',
      '--pretty',
      '--help',
    ],
  },
};

Map<String, Object?> _errorEnvelope(String code, String message) =>
    <String, Object?>{
      'schema': AutomationEnvelope.schema,
      'kind': 'error',
      'privacy': const AutomationPrivacy().toJson(),
      'data': <String, Object?>{'code': code, 'message': message},
    };

void _writeJson(Map<String, Object?> value, {required bool pretty}) {
  final encoded = pretty
      ? const JsonEncoder.withIndent('  ').convert(value)
      : jsonEncode(value);
  stdout.writeln(encoded);
}
