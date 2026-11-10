// App Vibration persistence, using real Hive storage in a temporary folder.
// "Restart" means closing all boxes and opening them again.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flow/data/services/app_haptics.dart';
import 'package:flow/data/services/settings_service.dart';
import 'package:flow/data/services/user_progress_adapter.dart';
import 'package:flow/domain/models/app_settings.dart';
import 'package:flow/domain/models/user_progress.dart';
import 'package:flow/ui/features/settings/view_models/settings_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rcbflow_vibration_test');
    Hive.init(dir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserProgressAdapter());
    }
    AppHaptics.enabled = true;
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
    AppHaptics.enabled = true;
  });

  Future<SettingsService> openSettings() async {
    final service = SettingsService();
    await service.init();
    return service;
  }

  Future<SettingsService> restart() async {
    await Hive.close();
    Hive.init(dir.path);
    return openSettings();
  }

  test('defaults to ON for a fresh install', () async {
    final service = await openSettings();
    expect(service.getSettings().isVibrationEnabled, isTrue);
    expect(const AppSettings().isVibrationEnabled, isTrue);
  });

  test('existing installs without the new key keep vibration ON and their '
      'other settings', () async {
    // Simulates settings saved by 1.0.0, before App Vibration existed.
    final box = await Hive.openBox('flow_settings');
    await box.put('hint_enabled', true);
    await box.put('sound_enabled', false);
    await box.put('theme_mode', 'dark');

    final s = (await restart()).getSettings();
    expect(s.isVibrationEnabled, isTrue);
    expect(s.isHintEnabled, isTrue);
    expect(s.isSoundEnabled, isFalse);
    expect(s.themeMode, ThemeMode.dark);
  });

  test(
    'turning it OFF persists across a restart and applies to haptics',
    () async {
      final vm = SettingsViewModel(settingsService: await openSettings());
      await vm.toggleVibrationEnabled(false);
      expect(vm.state.isVibrationEnabled, isFalse);
      expect(AppHaptics.enabled, isFalse, reason: 'applies immediately');
      vm.dispose();

      AppHaptics.enabled = true; // simulate a fresh process
      final service = await restart();
      expect(service.getSettings().isVibrationEnabled, isFalse);
      final restored = SettingsViewModel(settingsService: service);
      expect(AppHaptics.enabled, isFalse, reason: 'restored at start-up');
      restored.dispose();
    },
  );

  test('turning it back ON persists across a restart', () async {
    var vm = SettingsViewModel(settingsService: await openSettings());
    await vm.toggleVibrationEnabled(false);
    vm.dispose();

    vm = SettingsViewModel(settingsService: await restart());
    await vm.toggleVibrationEnabled(true);
    expect(AppHaptics.enabled, isTrue);
    vm.dispose();

    AppHaptics.enabled = false; // prove the restart restores it
    final service = await restart();
    expect(service.getSettings().isVibrationEnabled, isTrue);
    SettingsViewModel(settingsService: service).dispose();
    expect(AppHaptics.enabled, isTrue);
  });

  test(
    'toggling vibration leaves other settings and game progress untouched',
    () async {
      const progress = UserProgress(
        currentLevel: 8,
        highestLevelCompleted: 7,
        totalMoves: 120,
        bestMoves: {7: 9},
      );
      final progressBox = await Hive.openBox<UserProgress>(
        'flow_user_progress',
      );
      await progressBox.put('progress', progress);

      final vm = SettingsViewModel(settingsService: await openSettings());
      await vm.toggleHintEnabled(true);
      await vm.toggleSoundEnabled(false);
      await vm.setThemeMode(ThemeMode.light);
      await vm.toggleVibrationEnabled(false);
      await vm.toggleVibrationEnabled(true);
      await vm.toggleVibrationEnabled(false);
      vm.dispose();

      final s = (await restart()).getSettings();
      expect(s.isVibrationEnabled, isFalse);
      expect(s.isHintEnabled, isTrue);
      expect(s.isSoundEnabled, isFalse);
      expect(s.themeMode, ThemeMode.light);

      final restored = (await Hive.openBox<UserProgress>('flow_user_progress'))
          .get('progress')!;
      expect(restored.currentLevel, 8);
      expect(restored.highestLevelCompleted, 7);
      expect(restored.totalMoves, 120);
      expect(restored.bestMoves, {7: 9});
    },
  );
}
