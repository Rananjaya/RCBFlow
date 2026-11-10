// Persistence tests against real Hive storage in a temporary directory.
// They verify that settings and progress survive closing and reopening the
// local database, without touching the device or network.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flow/data/services/settings_service.dart';
import 'package:flow/data/services/user_progress_adapter.dart';
import 'package:flow/domain/models/app_settings.dart';
import 'package:flow/domain/models/user_progress.dart';
import 'package:flow/ui/features/settings/view_models/settings_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('rcbflow_hive_test');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  /// Simulates an app restart: closes every box and opens them again.
  Future<SettingsService> restartSettings() async {
    await Hive.close();
    Hive.init(dir.path);
    final service = SettingsService();
    await service.init();
    return service;
  }

  group('Settings persistence', () {
    test('defaults when nothing is stored', () async {
      final service = SettingsService();
      await service.init();

      final s = service.getSettings();
      expect(s.isHintEnabled, isFalse);
      expect(s.isSoundEnabled, isTrue);
      expect(s.themeMode, ThemeMode.system);
    });

    test('saved settings survive an app restart', () async {
      final service = SettingsService();
      await service.init();
      await service.saveSettings(
        const AppSettings(
          isHintEnabled: true,
          isSoundEnabled: false,
          themeMode: ThemeMode.dark,
        ),
      );

      final reloaded = (await restartSettings()).getSettings();
      expect(reloaded.isHintEnabled, isTrue);
      expect(reloaded.isSoundEnabled, isFalse);
      expect(reloaded.themeMode, ThemeMode.dark);
    });

    test('SettingsViewModel changes are persisted', () async {
      final service = SettingsService();
      await service.init();
      final vm = SettingsViewModel(settingsService: service);

      await vm.toggleSoundEnabled(false);
      await vm.toggleHintEnabled(true);
      await vm.setThemeMode(ThemeMode.light);
      vm.dispose();

      final reloaded = (await restartSettings()).getSettings();
      expect(reloaded.isSoundEnabled, isFalse);
      expect(reloaded.isHintEnabled, isTrue);
      expect(reloaded.themeMode, ThemeMode.light);
    });

    test('migrates the legacy app_theme key', () async {
      final box = await Hive.openBox('flow_settings');
      await box.put('app_theme', 'obsidian');
      final service = await restartSettings();
      expect(service.getSettings().themeMode, ThemeMode.dark);

      await Hive.box('flow_settings').put('app_theme', 'pastelButter');
      expect(service.getSettings().themeMode, ThemeMode.light);
    });

    test('unknown theme names fall back to system', () async {
      final box = await Hive.openBox('flow_settings');
      await box.put('theme_mode', 'neon');
      final service = await restartSettings();
      expect(service.getSettings().themeMode, ThemeMode.system);
    });
  });

  group('Progress persistence (UserProgressAdapter)', () {
    setUp(() {
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(UserProgressAdapter());
      }
    });

    test('every field round-trips through local storage', () async {
      const original = UserProgress(
        currentLevel: 12,
        highestLevelCompleted: 11,
        totalMoves: 345,
        bestMoves: {1: 4, 11: 20},
        bestTimeSeconds: {1: 9, 11: 75},
        savedLevelNumber: 12,
        savedBoard: [
          [1, 0, 1, 2],
          [2, 5, 6],
        ],
        savedMoveCount: 6,
        savedElapsedSeconds: 48,
      );

      var box = await Hive.openBox<UserProgress>('flow_user_progress');
      await box.put('progress', original);
      await Hive.close();
      Hive.init(dir.path);
      box = await Hive.openBox<UserProgress>('flow_user_progress');
      final restored = box.get('progress')!;

      expect(restored.currentLevel, 12);
      expect(restored.highestLevelCompleted, 11);
      expect(restored.totalMoves, 345);
      expect(restored.bestMoves, {1: 4, 11: 20});
      expect(restored.bestTimeSeconds, {1: 9, 11: 75});
      expect(restored.savedLevelNumber, 12);
      expect(restored.savedBoard, [
        [1, 0, 1, 2],
        [2, 5, 6],
      ]);
      expect(restored.savedMoveCount, 6);
      expect(restored.savedElapsedSeconds, 48);
    });

    test('a progress record without a saved game restores as null', () async {
      final box = await Hive.openBox<UserProgress>('flow_user_progress');
      await box.put('progress', const UserProgress(currentLevel: 2));
      await Hive.close();
      Hive.init(dir.path);

      final restored = (await Hive.openBox<UserProgress>('flow_user_progress'))
          .get('progress')!;
      expect(restored.currentLevel, 2);
      expect(restored.savedBoard, isNull);
      expect(restored.savedLevelNumber, isNull);
    });
  });
}
