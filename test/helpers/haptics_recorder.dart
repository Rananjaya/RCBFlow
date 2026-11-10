import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every haptic the app sends to the platform.
///
/// Flutter delivers [HapticFeedback] calls as `HapticFeedback.vibrate` messages
/// on [SystemChannels.platform]. This recorder intercepts that channel, so
/// tests see exactly what would reach the device. Nothing is recorded when
/// App Vibration is off.
class HapticsRecorder {
  /// One entry per haptic, e.g. `HapticFeedbackType.selectionClick`, or
  /// `vibrate` for a plain [HapticFeedback.vibrate].
  final List<String> calls = [];

  void start() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add((call.arguments as String?) ?? 'vibrate');
          }
          return null;
        });
  }

  void stop() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  }
}
