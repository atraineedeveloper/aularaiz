import 'package:flutter/foundation.dart';

/// Announces that local records changed because a sync operation merged data
/// from another device.
final class SyncRefreshNotifier extends ChangeNotifier {
  int _generation = 0;

  int get generation => _generation;

  void markDataChanged() {
    _generation += 1;
    notifyListeners();
  }
}
