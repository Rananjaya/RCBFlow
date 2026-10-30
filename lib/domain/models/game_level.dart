import 'package:flutter/material.dart';

@immutable
class GameLevel {
  const GameLevel({
    required this.levelNumber,
    required this.gridSize,
    required this.dots,
    required this.solution,
  });

  final int levelNumber;
  final int gridSize;
  final Map<int, List<int>> dots;
  final Map<int, List<int>> solution;

  int get totalCells => gridSize * gridSize;
  int get numColors => dots.length;

  int? dotAt(int cell) {
    for (final entry in dots.entries) {
      if (entry.value.contains(cell)) {
        return entry.key;
      }
    }
    return null;
  }

  bool isDot(int cell) => dotAt(cell) != null;

  GameLevel copyWith({
    int? levelNumber,
    int? gridSize,
    Map<int, List<int>>? dots,
    Map<int, List<int>>? solution,
  }) {
    return GameLevel(
      levelNumber: levelNumber ?? this.levelNumber,
      gridSize: gridSize ?? this.gridSize,
      dots: dots ?? this.dots,
      solution: solution ?? this.solution,
    );
  }
}
