import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production and demo use different physical database names', () {
    expect(
      StorageProfile.production.databaseName,
      isNot(StorageProfile.demo.databaseName),
    );
    expect(StorageProfile.production.databaseName, contains('production'));
    expect(StorageProfile.demo.databaseName, contains('demo'));
  });
}
