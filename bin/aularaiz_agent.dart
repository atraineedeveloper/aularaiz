import 'dart:convert';
import 'dart:io';

import 'package:aularaiz/application/automation/automation_models.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/domain/student_record/student_record_entry_kind.dart';
import 'package:aularaiz/infrastructure/automation/automation_runtime.dart';

Future<void> main(List<String> arguments) async {
  var pretty = arguments.contains('--pretty');
  try {
    final invocation = _Invocation.parse(arguments);
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
      throw const _CliFailure(
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
        'status' => await runtime.service.status(),
        'groups' => await runtime.service.listGroups(),
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
        _ => throw _UsageFailure('Comando desconocido: ${invocation.command}'),
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
  } on _CliFailure catch (error) {
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
    _writeJson(
      _errorEnvelope('data-state', error.message),
      pretty: pretty,
    );
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

final class _Invocation {
  const _Invocation({
    required this.command,
    required this.options,
    required this.flags,
  });

  factory _Invocation.parse(List<String> arguments) {
    const valueOptions = <String>{
      'database',
      'profile',
      'group',
      'month',
      'student',
      'kind',
      'date',
      'text',
    };
    const booleanFlags = <String>{
      'apply',
      'include-personal-data',
      'pretty',
      'help',
      'text-stdin',
    };

    String? command;
    final options = <String, String>{};
    final flags = <String>{};

    var index = 0;
    while (index < arguments.length) {
      final argument = arguments[index];
      if (!argument.startsWith('--')) {
        if (command != null) {
          throw _UsageFailure('Argumento inesperado: $argument');
        }
        command = argument;
        index++;
        continue;
      }

      final name = argument.substring(2);
      if (booleanFlags.contains(name)) {
        flags.add(name);
        index++;
        continue;
      }
      if (!valueOptions.contains(name)) {
        throw _UsageFailure('Opción desconocida: --$name');
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        throw _UsageFailure('Falta el valor de --$name.');
      }
      options[name] = arguments[index + 1];
      index += 2;
    }

    return _Invocation(command: command, options: options, flags: flags);
  }

  final String? command;
  final Map<String, String> options;
  final Set<String> flags;

  bool get apply => flags.contains('apply');
  bool get includePersonalData => flags.contains('include-personal-data');
  bool get pretty => flags.contains('pretty');
  bool get help => flags.contains('help');
  bool get textFromStdin => flags.contains('text-stdin');
  String? get databasePath => options['database'];

  StorageProfile get profile {
    final value = options['profile'] ?? StorageProfile.production.name;
    for (final profile in StorageProfile.values) {
      if (profile.name == value) return profile;
    }
    throw _UsageFailure('--profile debe ser production o demo.');
  }

  String requireOption(String name) {
    final value = options[name]?.trim();
    if (value == null || value.isEmpty) {
      throw _UsageFailure('El comando $command requiere --$name.');
    }
    return value;
  }
}

Future<String> _resolveNoteText(_Invocation invocation) async {
  final inlineText = invocation.options['text'];
  if (inlineText != null && invocation.textFromStdin) {
    throw _UsageFailure('Usa --text o --text-stdin, pero no ambos.');
  }
  if (!invocation.textFromStdin) {
    return invocation.requireOption('text');
  }

  final text = await utf8.decoder.bind(stdin).join();
  if (text.trim().isEmpty) {
    throw _UsageFailure('--text-stdin no recibió contenido.');
  }
  return text;
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
      <String, Object?>{'name': 'groups'},
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
    ],
    'global_options': <String>[
      '--database <path>',
      '--profile production|demo',
      '--include-personal-data',
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

class _CliFailure implements Exception {
  const _CliFailure(this.code, this.message, this.exitCode);

  final String code;
  final String message;
  final int exitCode;
}

final class _UsageFailure extends _CliFailure {
  _UsageFailure(String message) : super('usage', message, 2);
}
