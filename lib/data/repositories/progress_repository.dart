import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flow/data/services/hive_service.dart';
import 'package:flow/domain/models/user_progress.dart';

class ProgressRepository extends ChangeNotifier {
  ProgressRepository({required this.hiveService});

  final HiveService hiveService;
  UserProgress? _cachedProgress;

  Future<UserProgress> getProgress() async {
    if (_cachedProgress != null) return _cachedProgress!;
    _cachedProgress = await hiveService.getProgress();
    return _cachedProgress!;
  }

  Future<void> saveProgress(UserProgress progress) async {
    _cachedProgress = progress;
    await hiveService.saveProgress(progress);
    notifyListeners();
  }

  Future<void> completeLevel(int levelNumber, int moves, [int seconds = 0]) async {
    final current = await getProgress();
    final newHighest = math.max(current.highestLevelCompleted, levelNumber);
    final newCurrent = math.max(current.currentLevel, levelNumber + 1);
    var updated = current.copyWith(
      highestLevelCompleted: newHighest,
      currentLevel: newCurrent,
      totalMoves: current.totalMoves + moves,
    );
    updated = updated.recordLevelResult(levelNumber, moves, seconds);
    updated = updated.withoutSavedGame();
    await saveProgress(updated);
  }

  Future<void> saveCurrentBoard(
    int level,
    List<List<int>> board,
    int moves,
    int seconds,
  ) async {
    final current = await getProgress();
    await saveProgress(
      current.withSavedGame(
        levelNumber: level,
        board: board,
        moveCount: moves,
        elapsedSeconds: seconds,
      ),
    );
  }

  Future<void> resetProgress() async {
    _cachedProgress = null;
    await hiveService.clearProgress();
    notifyListeners();
  }
}
