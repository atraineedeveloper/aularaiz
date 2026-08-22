import 'dart:developer' as developer;

abstract final class SafeLog {
  static void frameworkError(Object error) {
    _write('framework_error', error.runtimeType.toString());
  }

  static void unhandledError(Object error) {
    _write('unhandled_error', error.runtimeType.toString());
  }

  static void _write(String category, String errorType) {
    developer.log(
      'category=$category errorType=$errorType',
      name: 'aularaiz.safe',
    );
  }
}
