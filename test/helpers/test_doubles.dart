// In-memory test doubles for the app's services.
//
// They replace Hive, audio playback and isolate-based level generation so that
// widget and view-model tests are fast, deterministic and need no platform
// channels, file system or network.

import 'package:flutter/material.dart';
import 'package:flow/data/services/hive_service.dart';
import 'package:flow/data/services/settings_service.dart';
import 'package:flow/data/services/sound_service.dart';
import 'package:flow/domain/models/app_settings.dart';
import 'package:flow/domain/models/game_level.dart';
import 'package:flow/domain/models/user_progress.dart';
import 'package:flow/domain/use_cases/level_generator.dart';

/// Stores progress in memory instead of a Hive box.
class InMemoryHiveService extends HiveService {
  InMemoryHiveService([this.progress = const UserProgress()]);

  UserProgress progress;
  int saveCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<UserProgress> getProgress() async => progress;

  @override
  Future<void> saveProgress(UserProgress progress) async {
    this.progress = progress;
    saveCount++;
  }

  @override
  Future<void> clearProgress() async {
    progress = const UserProgress();
  }
}

/// Stores settings in memory instead of a Hive box.
class InMemorySettingsService extends SettingsService {
  InMemorySettingsService([
    this.settings = const AppSettings(themeMode: ThemeMode.light),
  ]);

  AppSettings settings;
  int saveCount = 0;

  @override
  Future<void> init() async {}

  @override
  AppSettings getSettings() => settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
    saveCount++;
  }
}

/// Records sound requests instead of playing audio.
class FakeSoundService implements SoundService {
  final List<String> events = [];

  @override
  SettingsService? get settingsService => null;

  @override
  void playDragStep(int stepIndex) => events.add('step');

  @override
  void playDragRetract(int stepIndex) => events.add('retract');

  @override
  void playConnectionComplete() => events.add('connection');

  @override
  void playFlowComplete() => events.add('flow');

  @override
  void playLevelComplete() => events.add('level');

  @override
  void dispose() {}
}

/// A tiny, hand-made 3x3 level with three horizontal flows:
///
///     1 . 1        cells: 0 1 2
///     2 . 2               3 4 5
///     3 . 3               6 7 8
GameLevel threeByThreeLevel(int levelNumber) => GameLevel(
  levelNumber: levelNumber,
  gridSize: 3,
  dots: const {
    1: [0, 2],
    2: [3, 5],
    3: [6, 8],
  },
  solution: const {
    1: [0, 1, 2],
    2: [3, 4, 5],
    3: [6, 7, 8],
  },
);

/// Returns [threeByThreeLevel] synchronously (no isolates) and records calls.
class FakeLevelGenerator extends LevelGenerator {
  final List<int> requestedLevels = [];
  final List<Map<String, int>> requestedRandom = [];
  final List<int> pregenerateRequests = [];

  @override
  GameLevel generate(int levelNumber) {
    requestedLevels.add(levelNumber);
    return threeByThreeLevel(levelNumber);
  }

  @override
  Future<GameLevel> generateAsync(int levelNumber) async {
    requestedLevels.add(levelNumber);
    return threeByThreeLevel(levelNumber);
  }

  @override
  Future<GameLevel> generateRandomAsync({
    required int gridSize,
    required int seed,
  }) async {
    requestedRandom.add({'gridSize': gridSize, 'seed': seed});
    return threeByThreeLevel(-1);
  }

  @override
  void pregenerateAround(int currentLevel, {int range = 1}) {
    pregenerateRequests.add(currentLevel);
  }
}
