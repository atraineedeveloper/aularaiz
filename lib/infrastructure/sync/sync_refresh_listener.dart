import 'dart:async';

import 'package:aularaiz/infrastructure/sync/sync_refresh_notifier.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

final class SyncRefreshListener extends StatefulWidget {
  const SyncRefreshListener({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<SyncRefreshListener> createState() => _SyncRefreshListenerState();
}

final class _SyncRefreshListenerState extends State<SyncRefreshListener> {
  SyncRefreshNotifier? _notifier;
  bool _refreshing = false;
  bool _queued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SyncRefreshNotifier? next;
    try {
      next = context.read<SyncRefreshNotifier>();
    } on ProviderNotFoundException {
      next = null;
    }
    if (identical(_notifier, next)) return;
    _notifier?.removeListener(_onRefreshRequested);
    _notifier = next;
    _notifier?.addListener(_onRefreshRequested);
  }

  @override
  void dispose() {
    _notifier?.removeListener(_onRefreshRequested);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _onRefreshRequested() {
    if (_refreshing) {
      _queued = true;
      return;
    }
    _refreshing = true;
    unawaited(_runRefresh());
  }

  Future<void> _runRefresh() async {
    try {
      do {
        _queued = false;
        if (!mounted) return;
        await widget.onRefresh();
      } while (_queued);
    } finally {
      _refreshing = false;
    }
  }
}
