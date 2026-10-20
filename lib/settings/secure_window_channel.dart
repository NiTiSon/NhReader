import 'package:flutter/services.dart';

/// Turns Android's FLAG_SECURE on the activity: blocks screenshots and hides
/// the app window in the recents screen.
class SecureWindowChannel {
  static const MethodChannel _channel =
      MethodChannel('dev.nitis.nhreader/secure');

  static Future<void> apply(bool enabled) async {
    try {
      await _channel.invokeMethod('configSecureWindow', {'value': enabled});
    } on MissingPluginException {
      // No native handler (tests, iOS, desktop) — nothing to secure.
    }
  }
}
