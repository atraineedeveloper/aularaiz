import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:aularaiz/infrastructure/automation/agent_invocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses command, options and flags', () {
    final invocation = AgentInvocation.parse(const [
      'status',
      '--database',
      'C:\\demo.sqlite',
      '--profile',
      'demo',
      '--pretty',
    ]);

    expect(invocation.command, 'status');
    expect(invocation.databasePath, 'C:\\demo.sqlite');
    expect(invocation.profile, StorageProfile.demo);
    expect(invocation.pretty, isTrue);
    expect(invocation.apply, isFalse);
    expect(invocation.includePersonalData, isFalse);
  });

  test('rejects unknown options', () {
    expect(
      () => AgentInvocation.parse(const ['status', '--unknown']),
      throwsA(
        isA<AgentUsageFailure>().having((error) => error.code, 'code', 'usage'),
      ),
    );
  });

  test('rejects options without a value', () {
    expect(
      () => AgentInvocation.parse(const ['groups', '--group']),
      throwsA(isA<AgentUsageFailure>()),
    );
  });

  test('rejects multiple positional commands', () {
    expect(
      () => AgentInvocation.parse(const ['status', 'groups']),
      throwsA(isA<AgentUsageFailure>()),
    );
  });

  test('rejects invalid profiles', () {
    expect(
      () =>
          AgentInvocation.parse(const ['status', '--profile', 'other']).profile,
      throwsA(isA<AgentUsageFailure>()),
    );
  });

  test('requireOption reports the missing option', () {
    final invocation = AgentInvocation.parse(const ['groups']);
    expect(
      () => invocation.requireOption('group'),
      throwsA(
        isA<AgentUsageFailure>().having(
          (error) => error.message,
          'message',
          'El comando groups requiere --group.',
        ),
      ),
    );
  });

  test('delete with --apply fails without --confirm-delete', () {
    expect(
      () => AgentInvocation.parse(const [
        'group-delete',
        '--group',
        'group-1',
        '--apply',
      ]),
      throwsA(
        isA<AgentUsageFailure>().having(
          (error) => error.message,
          'message',
          'Las eliminaciones con --apply requieren --confirm-delete.',
        ),
      ),
    );

    expect(
      () => AgentInvocation.parse(const [
        'school-delete',
        '--school',
        'school-1',
        '--apply',
      ]),
      throwsA(isA<AgentUsageFailure>()),
    );

    expect(
      () => AgentInvocation.parse(const [
        'activity-delete',
        '--activity',
        'activity-1',
        '--apply',
      ]),
      throwsA(isA<AgentUsageFailure>()),
    );
  });

  test('delete with --apply and --confirm-delete is accepted', () {
    final invocation = AgentInvocation.parse(const [
      'group-delete',
      '--group',
      'group-1',
      '--apply',
      '--confirm-delete',
    ]);

    expect(invocation.command, 'group-delete');
    expect(invocation.apply, isTrue);
  });

  test('delete dry-run does not require --confirm-delete', () {
    final invocation = AgentInvocation.parse(const [
      'group-delete',
      '--group',
      'group-1',
    ]);

    expect(invocation.apply, isFalse);
  });

  test('non destructive mutations do not require --confirm-delete', () {
    final invocation = AgentInvocation.parse(const [
      'attendance-set',
      '--group',
      'group-1',
      '--student',
      'student-1',
      '--date',
      '2026-09-21',
      '--status',
      'absent',
      '--apply',
    ]);

    expect(invocation.apply, isTrue);
  });
}
