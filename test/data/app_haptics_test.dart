import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flow/data/services/app_haptics.dart';

import '../helpers/haptics_recorder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final recorder = HapticsRecorder();

  setUp(() {
    AppHaptics.enabled = true;
    recorder.calls.clear();
    recorder.start();
  });
  tearDown(() {
    recorder.stop();
    AppHaptics.enabled = true;
  });

  Future<void> fireAll() async {
    await AppHaptics.selectionClick();
    await AppHaptics.lightImpact();
    await AppHaptics.mediumImpact();
    await AppHaptics.heavyImpact();
    await AppHaptics.vibrate();
  }

  test('defaults to enabled', () {
    expect(AppHaptics.enabled, isTrue);
  });

  test('when enabled, every haptic type reaches the platform', () async {
    await fireAll();
    expect(recorder.calls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
      'vibrate',
    ]);
  });

  test('when disabled, nothing reaches the platform', () async {
    AppHaptics.enabled = false;
    await fireAll();
    expect(recorder.calls, isEmpty);
  });

  test('re-enabling restores haptics immediately', () async {
    AppHaptics.enabled = false;
    await AppHaptics.selectionClick();
    AppHaptics.enabled = true;
    await AppHaptics.selectionClick();
    expect(recorder.calls, ['HapticFeedbackType.selectionClick']);
  });

  test('no code in lib/ calls HapticFeedback directly (all go through '
      'AppHaptics, so the App Vibration setting is always respected)', () {
    const gateway = 'lib/data/services/app_haptics.dart';
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == gateway) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('HapticFeedback.')) {
          offenders.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Use AppHaptics instead');
  });
}
