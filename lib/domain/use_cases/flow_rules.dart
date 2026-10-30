import 'package:flow/domain/models/game_level.dart';

class FlowRules {
  const FlowRules._();

  static bool isFlowConnected(int color, List<int> path, GameLevel level) {
    final endpoints = level.dots[color];
    if (endpoints == null || endpoints.length < 2 || path.length < 2) {
      return false;
    }
    final first = path.first;
    final last = path.last;
    return (first == endpoints[0] && last == endpoints[1]) ||
        (first == endpoints[1] && last == endpoints[0]);
  }

  static int connectedFlowsCount(Map<int, List<int>> paths, GameLevel level) {
    int count = 0;
    for (final color in level.dots.keys) {
      final path = paths[color];
      if (path != null && isFlowConnected(color, path, level)) {
        count++;
      }
    }
    return count;
  }

  static int occupiedCellsCount(Map<int, List<int>> paths) {
    final visited = <int>{};
    for (final path in paths.values) {
      visited.addAll(path);
    }
    return visited.length;
  }

  static int pipePercentage(Map<int, List<int>> paths, GameLevel level) {
    if (level.totalCells == 0) return 0;
    final count = occupiedCellsCount(paths);
    return ((count / level.totalCells) * 100).round().clamp(0, 100);
  }

  static bool isComplete(Map<int, List<int>> paths, GameLevel level) {
    if (connectedFlowsCount(paths, level) != level.numColors) {
      return false;
    }
    return occupiedCellsCount(paths) == level.totalCells;
  }

  static bool canStep(
    int fromCell,
    int toCell,
    int color,
    GameLevel level,
  ) {
    final n = level.gridSize;
    if (toCell < 0 || toCell >= level.totalCells) return false;

    final fromR = fromCell ~/ n;
    final fromC = fromCell % n;
    final toR = toCell ~/ n;
    final toC = toCell % n;

    if ((fromR - toR).abs() + (fromC - toC).abs() != 1) return false;

    final otherDot = level.dotAt(toCell);
    if (otherDot != null && otherDot != color) return false;

    return true;
  }
}
