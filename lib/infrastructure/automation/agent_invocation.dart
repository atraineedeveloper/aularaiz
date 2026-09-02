import 'package:aularaiz/data/local/storage_profile.dart';

/// Failure surfaced by the agent CLI with a stable JSON error code and a
/// process exit code. Kept in a public library so the invocation contract
/// (including destructive-command gating) can be unit tested.
final class AgentCliFailure implements Exception {
  const AgentCliFailure(this.code, this.message, this.exitCode);

  final String code;
  final String message;
  final int exitCode;
}

final class AgentUsageFailure extends AgentCliFailure {
  AgentUsageFailure(String message) : super('usage', message, 2);
}

final class AgentInvocation {
  const AgentInvocation({
    required this.command,
    required this.options,
    required this.flags,
  });

  factory AgentInvocation.parse(List<String> arguments) {
    const valueOptions = <String>{
      'database',
      'profile',
      'group',
      'month',
      'student',
      'kind',
      'date',
      'text',
      'status',
      'grade',
      'list-number',
      'school',
      'school-name',
      'school-year',
      'school-year-id',
      'starts-on',
      'ends-on',
      'group-name',
      'grades',
      'shift',
      'cct',
      'organization',
      'state',
      'municipality',
      'locality',
      'school-zone',
      'school-sector',
      'supervisor-name',
      'leadership-name',
      'leadership-role',
      'teacher-name',
      'teaching-role',
      'given-names',
      'first-surname',
      'second-surname',
      'sex',
      'birth-date',
      'title',
      'methodology',
      'project',
      'activity',
      'formative-field',
    };
    const booleanFlags = <String>{
      'apply',
      'include-personal-data',
      'pretty',
      'help',
      'text-stdin',
      'confirm-delete',
    };

    String? command;
    final options = <String, String>{};
    final flags = <String>{};

    var index = 0;
    while (index < arguments.length) {
      final argument = arguments[index];
      if (!argument.startsWith('--')) {
        if (command != null) {
          throw AgentUsageFailure('Argumento inesperado: $argument');
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
        throw AgentUsageFailure('Opción desconocida: --$name');
      }
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        throw AgentUsageFailure('Falta el valor de --$name.');
      }
      options[name] = arguments[index + 1];
      index += 2;
    }

    const destructive = {'school-delete', 'group-delete', 'activity-delete'};
    if (flags.contains('apply') &&
        destructive.contains(command) &&
        !flags.contains('confirm-delete')) {
      throw AgentUsageFailure(
        'Las eliminaciones con --apply requieren --confirm-delete.',
      );
    }
    return AgentInvocation(command: command, options: options, flags: flags);
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
    throw AgentUsageFailure('--profile debe ser production o demo.');
  }

  String requireOption(String name) {
    final value = options[name]?.trim();
    if (value == null || value.isEmpty) {
      throw AgentUsageFailure('El comando $command requiere --$name.');
    }
    return value;
  }
}
