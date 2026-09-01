import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

abstract final class SafeLog {
  static const _maximumBytes = 1024 * 1024;
  static File? _file;

  static String? get filePath => _file?.path;

  static Future<void> initialize() async {
    try {
      final directory = await getApplicationSupportDirectory();
      _file = File('${directory.path}${Platform.pathSeparator}aularaiz.log');
      await _rotateIfNeeded();
      _event('app_started');
    } catch (_) {}
  }

  static void operationFailure(String operation, Object error, {String? code}) {
    _event(
      'operation_failed operation=$operation errorType=${error.runtimeType}'
      '${code == null ? '' : ' code=$code'}',
    );
  }

  static void operationSuccess(String operation) {
    _event('operation_succeeded operation=$operation');
  }

  static void frameworkError(Object error) {
    _write('framework_error', error.runtimeType.toString());
  }

  static void unhandledError(Object error) {
    _write('unhandled_error', error.runtimeType.toString());
  }

  static void recoveryEvent(String event) {
    _event('category=recovery_event event=$event');
  }

  static void recoveryFailure(Object error) {
    _write('recovery_failure', error.runtimeType.toString());
  }

  static void _write(String category, String errorType) {
    _event('category=$category errorType=$errorType');
  }

  static void _event(String message) {
    developer.log(message, name: 'aularaiz.safe');
    final file = _file;
    if (file == null) return;
    file
        .writeAsString(
          '${DateTime.now().toUtc().toIso8601String()} $message\n',
          mode: FileMode.append,
          flush: true,
        )
        .ignore();
  }

  static Future<void> _rotateIfNeeded() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    if (await file.length() <= _maximumBytes) return;
    final previous = File('${file.path}.previous');
    if (await previous.exists()) await previous.delete();
    await file.rename(previous.path);
  }
}
