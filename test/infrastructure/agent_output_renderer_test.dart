import 'package:aularaiz/infrastructure/automation/agent_invocation.dart';
import 'package:aularaiz/infrastructure/automation/agent_output_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('human output is the default even with pretty', () {
    expect(AgentInvocation.parse(['schools']).jsonOutput, isFalse);
    expect(AgentInvocation.parse(['schools', '--pretty']).jsonOutput, isFalse);
    expect(
      AgentInvocation.parse(['schools', '--format', 'json']).jsonOutput,
      isTrue,
    );
    expect(
      () => AgentInvocation.parse(['--format', 'xml']),
      throwsA(isA<AgentUsageFailure>()),
    );
    expect(
      () => AgentInvocation.parse(['--format']),
      throwsA(isA<AgentUsageFailure>()),
    );
  });
  test('lists are rendered as tables without modifying the envelope', () {
    final data = {
      'kind': 'schools',
      'data': {
        'schools': [
          {'id': 's-1', 'name': 'Benito Juárez'},
          {'id': 's-2', 'name': 'Otra escuela'},
        ],
      },
    };
    final output = renderAgentOutput(data);
    expect(output, contains('Escuelas'));
    expect(output, contains('ID'));
    expect(output, contains('Benito Juárez'));
    expect(output, contains('2 registro(s)'));
    expect(data['data'], {
      'schools': [
        {'id': 's-1', 'name': 'Benito Juárez'},
        {'id': 's-2', 'name': 'Otra escuela'},
      ],
    });
  });
  test('minimized output stays minimized and empty lists are readable', () {
    final output = renderAgentOutput({
      'kind': 'students',
      'data': {'student_count': 3, 'students': <Object>[]},
    });
    expect(output, contains('Alumnos: 3'));
    expect(output, contains('Sin registros'));
    expect(output, isNot(contains('student_id')));
  });
  test('nested and wide rows retain full identifiers and values', () {
    final id = 'a' * 120;
    final output = renderAgentOutput({
      'kind': 'groups',
      'data': {
        'groups': [
          {
            'id': id,
            'school': {'name': 'Primaria'},
          },
        ],
      },
    });
    expect(output, contains(id));
    expect(output, contains('Primaria'));
  });
  test('simulation, applied changes and errors have explicit messages', () {
    expect(
      renderAgentOutput({
        'kind': 'school-update',
        'data': {'dry_run': true},
      }),
      contains('no se guardaron cambios'),
    );
    expect(
      renderAgentOutput({
        'kind': 'school-update',
        'data': {'applied': true},
      }),
      contains('Cambio guardado'),
    );
    expect(
      renderAgentOutput({
        'kind': 'error',
        'data': {'code': 'usage', 'message': 'Falta el grupo'},
      }),
      contains('Error [usage]: Falta el grupo'),
    );
  });
  test('terminal control characters are removed from user fields', () {
    expect(
      renderAgentOutput({
        'kind': 'schools',
        'data': {'name': 'Escuela\x1b[2J\nPrueba'},
      }),
      isNot(contains('\x1b')),
    );
  });
}
