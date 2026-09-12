import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final class WindowTitleService {
  const WindowTitleService._();

  static const MethodChannel _channel = MethodChannel('aularaiz/window');

  static Future<void> setTitle(String title) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    try {
      await _channel.invokeMethod<void>('setTitle', title.trim());
    } on MissingPluginException {
      // Non-Windows builds and some tests do not register the native channel.
    }
  }
}
