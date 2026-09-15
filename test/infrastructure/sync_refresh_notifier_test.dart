import 'package:aularaiz/infrastructure/sync/sync_refresh_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notifies listeners when synced data changes', () {
    final notifier = SyncRefreshNotifier();
    var calls = 0;
    notifier.addListener(() {
      calls += 1;
    });

    expect(notifier.generation, 0);

    notifier.markDataChanged();

    expect(notifier.generation, 1);
    expect(calls, 1);
  });
}
