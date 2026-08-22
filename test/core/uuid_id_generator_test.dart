import 'package:aularaiz/core/id/uuid_id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UUID generator returns distinct RFC 4122 v4-shaped identifiers', () {
    final generator = UuidIdGenerator();

    final first = generator.newId();
    final second = generator.newId();

    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(first, matches(pattern));
    expect(second, matches(pattern));
    expect(second, isNot(first));
  });
}
