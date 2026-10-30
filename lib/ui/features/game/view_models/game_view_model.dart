import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flow/data/repositories/progress_repository.dart';
import 'package:flow/data/services/settings_service.dart';
import 'package:flow/data/services/sound_service.dart';
import 'package:flow/domain/models/game_level.dart';
import 'package:flow/domain/use_cases/flow_rules.dart';
import 'package:flow/domain/use_cases/level_generator.dart';

@immutable
class GameViewModelState {
  const GameViewModelState({
    this.level,
    this.paths = const {},
    this.activeColor,
    this.history = const [],
    this.isLoading = false,
    this.isComplete = false,
    this.moveCount = 0,
    this.elapsedSeconds = 0,
    this.hintColor,
    this.error,
    this.isRandomMode = false,
    this.randomDifficulty,
    this.randomSeed,
    this.randomGridSize,
  });

  final GameLevel? level;
  final Map<int, List<int>> paths;
  final int? activeColor;
  final List<Map<int, List<int>>> history;
  final bool isLoading;
  final bool isComplete;
  final int moveCount;
  final int elapsedSeconds;
  final int? hintColor;
  final String? error;
  final bool isRandomMode;
  final String? randomDifficulty;
  final int? randomSeed;
  final int? randomGridSize;

  int get totalCells => level?.totalCells ?? 0;
  int get connectedCount =>
      level == null ? 0 : FlowRules.connectedFlowsCount(paths, level!);
  int get pipePercent =>
      level == null ? 0 : FlowRules.pipePercentage(paths, level!);
  List<List<int>> get board =>
      paths.entries.map((e) => [e.key, ...e.value]).toList();

  GameViewModelState copyWith({
    GameLevel? level,
    Map<int, List<int>>? paths,
    int? activeColor,
    bool clearActiveColor = false,
    List<Map<int, List<int>>>? history,
    bool? isLoading,
    bool? isComplete,
    int? moveCount,
    int? elapsedSeconds,
    int? hintColor,
    bool clearHint = false,
    String? error,
    bool? isRandomMode,
    String? randomDifficulty,
    int? randomSeed,
    int? randomGridSize,
  }) {
    return GameViewModelState(
      level: level ?? this.level,
      paths: paths ?? this.paths,
      activeColor:
          clearActiveColor ? null : (activeColor ?? this.activeColor),
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      isComplete: isComplete ?? this.isComplete,
      moveCount: moveCount ?? this.moveCount,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      hintColor: clearHint ? null : (hintColor ?? this.hintColor),
      error: error,
      isRandomMode: isRandomMode ?? this.isRandomMode,
      randomDifficulty: randomDifficulty ?? this.randomDifficulty,
      randomSeed: randomSeed ?? this.randomSeed,
      randomGridSize: randomGridSize ?? this.randomGridSize,
    );
  }
}

class GameViewModel extends StateNotifier<GameViewModelState> {
  GameViewModel({
    required this.progressRepository,
    required this.levelGenerator,
    required this.settingsService,
    this.soundService,
  }) : super(const GameViewModelState());

  final ProgressRepository progressRepository;
  final LevelGenerator levelGenerator;
  final SettingsService settingsService;
  final SoundService? soundService;

  Timer? _timer;
  Timer? _hintTimer;
  bool _hasSavedCompletion = false;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _stopTimer();
        return;
      }
      if (state.isComplete) {
        _timer?.cancel();
        return;
      }
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Map<int, List<int>> _clonePaths(Map<int, List<int>> source) {
    return source.map((k, v) => MapEntry(k, List<int>.from(v)));
  }

  Future<void> loadLevel(int levelNumber) async {
    _hasSavedCompletion = false;
    state = const GameViewModelState(isLoading: true);

    try {
      final level = await levelGenerator.generateAsync(levelNumber);
      if (!mounted) return;

      final progress = await progressRepository.getProgress();
      if (!mounted) return;

      final Map<int, List<int>> paths = {};
      int moveCount = 0;
      int elapsed = 0;

      if (progress.savedLevelNumber == levelNumber &&
          progress.savedBoard != null &&
          progress.savedBoard!.isNotEmpty) {
        for (final list in progress.savedBoard!) {
          if (list.length >= 2) {
            paths[list.first] = list.sublist(1);
          }
        }
        moveCount = progress.savedMoveCount;
        elapsed = progress.savedElapsedSeconds;
      }

      final isComplete = FlowRules.isComplete(paths, level);

      state = GameViewModelState(
        level: level,
        paths: paths,
        moveCount: moveCount,
        elapsedSeconds: elapsed,
        isComplete: isComplete,
      );

      if (!isComplete) _startTimer();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load level: $e',
      );
    }
  }

  int _parseGridSize(String difficulty) {
    final lower = difficulty.toLowerCase().trim();
    final match = RegExp(r'(\d+)\s*x\s*(\d+)').firstMatch(lower);
    if (match != null) {
      final size = int.tryParse(match.group(1)!);
      if (size != null && size >= 5 && size <= 14) return size;
    }
    switch (lower) {
      case 'easy':
        return 5;
      case 'medium':
        return 7;
      case 'hard':
        return 9;
      case 'expert':
        return 12;
      case 'master':
        return 14;
      default:
        return 5;
    }
  }

  Future<void> loadRandomLevel(String difficulty, {int? seed}) async {
    _hasSavedCompletion = false;
    final int levelSeed = seed ?? DateTime.now().millisecondsSinceEpoch;
    final int gridSize = _parseGridSize(difficulty);

    state = GameViewModelState(
      isLoading: true,
      isRandomMode: true,
      randomDifficulty: difficulty,
      randomSeed: levelSeed,
      randomGridSize: gridSize,
    );

    try {
      final level = await levelGenerator.generateRandomAsync(
        gridSize: gridSize,
        seed: levelSeed,
      );
      if (!mounted) return;

      final isComplete = FlowRules.isComplete(const {}, level);

      state = state.copyWith(
        level: level,
        paths: const {},
        moveCount: 0,
        elapsedSeconds: 0,
        isLoading: false,
        isComplete: isComplete,
        randomGridSize: gridSize,
      );

      if (!isComplete) _startTimer();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load random level: $e',
      );
    }
  }

  void startDrag(int cell) {
    final level = state.level;
    if (state.isComplete || level == null) return;

    final dotColor = level.dotAt(cell);
    final newPaths = _clonePaths(state.paths);
    final history = List<Map<int, List<int>>>.from(state.history)
      ..add(_clonePaths(state.paths));

    if (dotColor != null) {
      newPaths[dotColor] = [cell];
      HapticFeedback.selectionClick();
      soundService?.playDragStep(1);
      state = state.copyWith(
        paths: newPaths,
        activeColor: dotColor,
        history: history,
        clearHint: true,
      );
      return;
    }

    for (final entry in state.paths.entries) {
      final path = entry.value;
      if (path.contains(cell)) {
        final color = entry.key;
        final idx = path.indexOf(cell);
        newPaths[color] = path.sublist(0, idx + 1);
        HapticFeedback.selectionClick();
        soundService?.playDragStep(newPaths[color]!.length);
        state = state.copyWith(
          paths: newPaths,
          activeColor: color,
          history: history,
          clearHint: true,
        );
        return;
      }
    }
  }

  void dragStep(int targetCell) {
    final level = state.level;
    final activeColor = state.activeColor;
    if (state.isComplete || level == null || activeColor == null) return;

    final newPaths = _clonePaths(state.paths);
    final path = newPaths[activeColor] ?? [];
    if (path.isEmpty) return;

    final lastCell = path.last;
    if (targetCell == lastCell) return;

    final n = level.gridSize;
    final fromR = lastCell ~/ n;
    final fromC = lastCell % n;
    final toR = targetCell ~/ n;
    final toC = targetCell % n;

    if ((fromR - toR).abs() + (fromC - toC).abs() != 1) return;

    if (path.length >= 2 && targetCell == path[path.length - 2]) {
      path.removeLast();
      newPaths[activeColor] = path;
      HapticFeedback.lightImpact();
      soundService?.playDragRetract(path.length);
      state = state.copyWith(paths: newPaths);
      return;
    }

    if (path.contains(targetCell)) {
      final idx = path.indexOf(targetCell);
      newPaths[activeColor] = path.sublist(0, idx + 1);
      soundService?.playDragRetract(newPaths[activeColor]!.length);
      state = state.copyWith(paths: newPaths);
      return;
    }

    final otherDot = level.dotAt(targetCell);
    if (otherDot != null && otherDot != activeColor) return;

    for (final c in newPaths.keys.toList()) {
      if (c != activeColor) {
        final otherPath = newPaths[c]!;
        if (otherPath.contains(targetCell)) {
          final cutIdx = otherPath.indexOf(targetCell);
          newPaths[c] = otherPath.sublist(0, cutIdx);
          if (newPaths[c]!.isEmpty) {
            newPaths.remove(c);
          }
        }
      }
    }

    path.add(targetCell);
    newPaths[activeColor] = path;
    HapticFeedback.selectionClick();

    final endpoints = level.dots[activeColor];
    if (endpoints != null &&
        endpoints.length >= 2 &&
        (targetCell == endpoints[0] || targetCell == endpoints[1])) {
      HapticFeedback.mediumImpact();
      soundService?.playConnectionComplete();
      state = state.copyWith(
        paths: newPaths,
        clearActiveColor: true,
      );
      _checkCompletion(newPaths);
      return;
    }

    soundService?.playDragStep(path.length);
    state = state.copyWith(paths: newPaths);
  }

  void endDrag() {
    if (state.activeColor == null) return;
    final paths = state.paths;
    state = state.copyWith(
      clearActiveColor: true,
      moveCount: state.moveCount + 1,
    );
    _checkCompletion(paths);
  }

  void _checkCompletion(Map<int, List<int>> paths) {
    final level = state.level;
    if (level == null) return;

    final complete = FlowRules.isComplete(paths, level);
    if (complete && !state.isComplete) {
      _stopTimer();
      state = state.copyWith(isComplete: true);
      soundService?.playLevelComplete();
      completeLevel();
      return;
    }

    if (!state.isRandomMode && !state.isComplete) {
      progressRepository.saveCurrentBoard(
        state.level!.levelNumber,
        state.board,
        state.moveCount,
        state.elapsedSeconds,
      );
    }
  }

  void undo() {
    if (state.history.isEmpty) return;
    final newHistory = List<Map<int, List<int>>>.from(state.history);
    final lastState = newHistory.removeLast();
    soundService?.playDragRetract(1);
    state = state.copyWith(
      paths: lastState,
      history: newHistory,
      moveCount: state.moveCount + 1,
      clearActiveColor: true,
      clearHint: true,
    );
    _checkCompletion(lastState);
  }

  void clearBoard() {
    if (state.paths.isEmpty) return;
    final history = List<Map<int, List<int>>>.from(state.history)
      ..add(_clonePaths(state.paths));
    soundService?.playDragRetract(0);
    state = state.copyWith(
      paths: const {},
      history: history,
      moveCount: state.moveCount + 1,
      clearActiveColor: true,
      clearHint: true,
    );
    _checkCompletion(const {});
  }

  void revealHint() {
    final level = state.level;
    if (level == null || state.isComplete) return;

    for (final color in level.dots.keys) {
      final path = state.paths[color];
      final isDone = path != null && FlowRules.isFlowConnected(color, path, level);
      if (!isDone) {
        final solutionPath = level.solution[color];
        if (solutionPath != null) {
          final newPaths = _clonePaths(state.paths);
          for (final c in newPaths.keys.toList()) {
            if (c != color) {
              final other = newPaths[c]!;
              if (other.any((cell) => solutionPath.contains(cell))) {
                final cutIdx =
                    other.indexWhere((cell) => solutionPath.contains(cell));
                newPaths[c] = other.sublist(0, cutIdx);
                if (newPaths[c]!.isEmpty) {
                  newPaths.remove(c);
                }
              }
            }
          }
          newPaths[color] = List<int>.from(solutionPath);

          _hintTimer?.cancel();
          soundService?.playConnectionComplete();
          state = state.copyWith(
            paths: newPaths,
            hintColor: color,
            moveCount: state.moveCount + 1,
          );

          _hintTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              state = state.copyWith(clearHint: true);
            }
          });

          _checkCompletion(newPaths);
          return;
        }
      }
    }
  }

  Future<void> completeLevel() async {
    if (_hasSavedCompletion) return;
    _hasSavedCompletion = true;
    _stopTimer();
    if (state.isRandomMode || state.level == null) return;

    await progressRepository.completeLevel(
      state.level!.levelNumber,
      state.moveCount,
      state.elapsedSeconds,
    );
  }

  void resetLevel() {
    if (state.isRandomMode) {
      loadRandomLevel(
        state.randomDifficulty ?? 'Easy',
        seed: state.randomSeed,
      );
    } else if (state.level != null) {
      loadLevel(state.level!.levelNumber);
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _hintTimer?.cancel();
    super.dispose();
  }
}
