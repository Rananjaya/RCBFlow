import 'package:flutter/services.dart';

/// The single entry point for all of RCBFlow's haptic feedback (vibration).
///
/// Every vibration in the app goes through this class, so the **App
/// Vibration** setting is always respected. Don't call [HapticFeedback]
/// directly anywhere else in `lib/`; a test
/// (`test/data/app_haptics_test.dart`) fails if you do.
///
/// [enabled] mirrors `AppSettings.isVibrationEnabled`. `main.dart` sets it at
/// start-up and `SettingsViewModel` updates it whenever the setting changes,
/// so a change takes effect immediately. When disabled, nothing reaches the
/// platform, so Android's own system and accessibility vibration is untouched.
abstract final class AppHaptics {
  /// Whether app haptics are on. Defaults to true, matching the setting's
  /// default.
  static bool enabled = true;

  static Future<void> selectionClick() =>
      enabled ? HapticFeedback.selectionClick() : Future<void>.value();

  static Future<void> lightImpact() =>
      enabled ? HapticFeedback.lightImpact() : Future<void>.value();

  static Future<void> mediumImpact() =>
      enabled ? HapticFeedback.mediumImpact() : Future<void>.value();

  static Future<void> heavyImpact() =>
      enabled ? HapticFeedback.heavyImpact() : Future<void>.value();

  static Future<void> vibrate() =>
      enabled ? HapticFeedback.vibrate() : Future<void>.value();
}
