import 'package:aularaiz/app/runtime/app_runtime_config.dart';
import 'package:aularaiz/data/local/storage_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production is the default runtime profile', () {
    final config = AppRuntimeConfig.fromArguments(const []);

    expect(config.storageProfile, StorageProfile.production);
    expect(config.isDemo, isFalse);
    expect(config.resetDemo, isFalse);
  });

  test('--demo selects isolated demo storage without resetting it', () {
    final config = AppRuntimeConfig.fromArguments(const ['--demo']);

    expect(config.storageProfile, StorageProfile.demo);
    expect(config.isDemo, isTrue);
    expect(config.resetDemo, isFalse);
  });

  test('--demo-reset implies demo mode and requests a reset', () {
    final config = AppRuntimeConfig.fromArguments(const ['--demo-reset']);

    expect(config.storageProfile, StorageProfile.demo);
    expect(config.isDemo, isTrue);
    expect(config.resetDemo, isTrue);
  });

  test('runtime switches tolerate casing and surrounding whitespace', () {
    final config = AppRuntimeConfig.fromArguments(const ['  --DEMO-RESET  ']);

    expect(config.storageProfile, StorageProfile.demo);
    expect(config.resetDemo, isTrue);
  });
}
