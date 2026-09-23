import 'package:aularaiz/infrastructure/sync/sync_device_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters technical loopback names from linked device labels', () {
    expect(SyncDeviceRegistry.friendlyDeviceName('localhost'), isNull);
    expect(SyncDeviceRegistry.friendlyDeviceName('127.0.0.1'), isNull);
    expect(SyncDeviceRegistry.friendlyDeviceName('::1'), isNull);
    expect(
      SyncDeviceRegistry.friendlyDeviceName(' Laptop del maestro '),
      'Laptop del maestro',
    );
  });
}
