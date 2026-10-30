import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flow/domain/models/game_level.dart';

class LevelGenerator {
  final Map<int, GameLevel> _cache = {};
  final Set<int> _generating = {};

  GameLevel generate(int levelNumber) {
    GameLevel level;
    if (_cache.containsKey(levelNumber)) {
      level = _cache.remove(levelNumber)!;
    } else {
      level = _generateInternal(levelNumber);
    }
    _generating.remove(levelNumber);
    _pregenerateNext(levelNumber + 1);
    return level;
  }

  Future<GameLevel> generateAsync(int levelNumber) async {
    GameLevel level;
    if (_cache.containsKey(levelNumber)) {
      level = _cache.remove(levelNumber)!;
    } else {
      level = await compute(_isolateGenerate, levelNumber);
    }
    _generating.remove(levelNumber);
    _pregenerateNext(levelNumber + 1);
    return level;
  }

  GameLevel _generateInternal(int levelNumber) {
    final random = Random(levelNumber * 10007 + 31);
    final gridSize = _getGridSize(levelNumber);
    final numColors = _getColorCount(levelNumber, gridSize);
    return _generateLevelWithSeed(levelNumber, gridSize, numColors, random);
  }

  void pregenerateAround(int currentLevel, {int range = 1}) {
    for (int i = 0; i <= range; i++) {
      final levelNumber = currentLevel + i;
      if (levelNumber < 1) continue;
      if (!_cache.containsKey(levelNumber) &&
          !_generating.contains(levelNumber)) {
        _generating.add(levelNumber);
        compute(_isolateGenerate, levelNumber)
            .then((level) {
              _cache[levelNumber] = level;
              _generating.remove(levelNumber);
            })
            .catchError((_) {
              _generating.remove(levelNumber);
            });
      }
    }
  }

  void _pregenerateNext(int startLevel) {
    pregenerateAround(startLevel, range: 1);
  }

  static GameLevel _isolateGenerate(int levelNumber) {
    return LevelGenerator()._generateInternal(levelNumber);
  }

  static GameLevel _isolateGenerateRandom(Map<String, int> params) {
    return LevelGenerator().generateRandom(
      gridSize: params['gridSize']!,
      seed: params['seed']!,
    );
  }

  Future<GameLevel> generateRandomAsync({
    required int gridSize,
    required int seed,
  }) {
    return compute(_isolateGenerateRandom, {
      'gridSize': gridSize,
      'seed': seed,
    });
  }

  GameLevel generateRandom({required int gridSize, required int seed}) {
    final random = Random(seed);
    final numColors = _getRandomColorCount(gridSize);
    return _generateLevelWithSeed(-1, gridSize, numColors, random);
  }

  int _getGridSize(int level) {
    if (level <= 25) return 5;
    if (level <= 50) return 6;
    if (level <= 75) return 7;
    if (level <= 100) return 8;
    if (level <= 125) return 9;
    if (level <= 150) return 10;
    if (level <= 175) return 11;
    if (level <= 200) return 12;
    if (level <= 225) return 13;
    return 14;
  }

  int _getColorCount(int level, int gridSize) {
    if (level > 250) {
      return 10 + ((level - 251) % 3);
    }
    final tierIndex = (level - 1) % 25;
    switch (gridSize) {
      case 5:
        return tierIndex < 6 ? 3 : (tierIndex < 16 ? 4 : 5);
      case 6:
        return tierIndex < 7 ? 4 : (tierIndex < 17 ? 5 : 6);
      case 7:
        return tierIndex < 8 ? 5 : (tierIndex < 18 ? 6 : 7);
      case 8:
        return tierIndex < 8 ? 6 : (tierIndex < 18 ? 7 : 8);
      case 9:
        return tierIndex < 8 ? 7 : (tierIndex < 18 ? 8 : 9);
      case 10:
        return tierIndex < 8 ? 8 : (tierIndex < 18 ? 9 : 10);
      case 11:
        return tierIndex < 8 ? 8 : (tierIndex < 18 ? 9 : 10);
      case 12:
        return tierIndex < 8 ? 9 : (tierIndex < 18 ? 10 : 11);
      case 13:
        return tierIndex < 8 ? 9 : (tierIndex < 18 ? 10 : 11);
      default:
        return tierIndex < 8 ? 10 : (tierIndex < 17 ? 11 : 12);
    }
  }

  int _getRandomColorCount(int gridSize) {
    if (gridSize <= 5) return 4;
    if (gridSize == 6) return 5;
    if (gridSize == 7) return 6;
    if (gridSize == 8) return 7;
    if (gridSize == 9) return 8;
    if (gridSize == 10) return 9;
    if (gridSize == 11) return 9;
    if (gridSize == 12) return 10;
    if (gridSize == 13) return 11;
    return 12;
  }

  GameLevel _generateLevelWithSeed(
    int levelNumber,
    int n,
    int numColors,
    Random rng,
  ) {
    final total = n * n;
    final board = List<int>.filled(total, 0);

    List<int> getNeighbors(int cell) {
      final r = cell ~/ n;
      final c = cell % n;
      final res = <int>[];
      if (r > 0) res.add((r - 1) * n + c);
      if (r < n - 1) res.add((r + 1) * n + c);
      if (c > 0) res.add(r * n + c - 1);
      if (c < n - 1) res.add(r * n + c + 1);
      res.shuffle(rng);
      return res;
    }

    for (int attempt = 0; attempt < 300; attempt++) {
      board.fillRange(0, total, 0);
      final paths = List<List<int>>.generate(numColors, (_) => []);

      final allCells = List<int>.generate(total, (i) => i)..shuffle(rng);
      final seeds = <int>[];
      for (final cell in allCells) {
        if (seeds.length == numColors) break;
        final adjacent = seeds.any((s) {
          final r1 = s ~/ n;
          final c1 = s % n;
          final r2 = cell ~/ n;
          final c2 = cell % n;
          return (r1 - r2).abs() + (c1 - c2).abs() <= 1;
        });
        if (!adjacent) {
          seeds.add(cell);
        }
      }
      if (seeds.length < numColors) continue;

      for (int i = 0; i < numColors; i++) {
        paths[i].add(seeds[i]);
        board[seeds[i]] = i + 1;
      }

      bool grew = true;
      while (grew) {
        grew = false;
        final colorIndices = List<int>.generate(numColors, (i) => i)
          ..shuffle(rng);

        for (final c in colorIndices) {
          final head = paths[c].last;
          final tail = paths[c].first;

          final headNbs = getNeighbors(head).where((nb) => board[nb] == 0).toList();
          if (headNbs.isNotEmpty) {
            headNbs.sort((a, b) {
              final aFree = getNeighbors(a).where((x) => board[x] == 0).length;
              final bFree = getNeighbors(b).where((x) => board[x] == 0).length;
              return aFree.compareTo(bFree);
            });
            final next = headNbs.first;
            paths[c].add(next);
            board[next] = c + 1;
            grew = true;
            continue;
          }

          final tailNbs = getNeighbors(tail).where((nb) => board[nb] == 0).toList();
          if (tailNbs.isNotEmpty) {
            tailNbs.sort((a, b) {
              final aFree = getNeighbors(a).where((x) => board[x] == 0).length;
              final bFree = getNeighbors(b).where((x) => board[x] == 0).length;
              return aFree.compareTo(bFree);
            });
            final next = tailNbs.first;
            paths[c].insert(0, next);
            board[next] = c + 1;
            grew = true;
          }
        }
      }

      final full = board.every((x) => x > 0);
      final minLength = attempt < 180 ? 3 : 2;
      final validLengths = paths.every((p) {
        if (p.length < minLength) return false;
        if (attempt < 150) {
          final r1 = p.first ~/ n;
          final c1 = p.first % n;
          final r2 = p.last ~/ n;
          final c2 = p.last % n;
          return (r1 - r2).abs() + (c1 - c2).abs() >= 2;
        }
        return true;
      });

      if (full && validLengths) {
        final dots = <int, List<int>>{};
        final solution = <int, List<int>>{};
        for (int i = 0; i < numColors; i++) {
          final colorId = i + 1;
          dots[colorId] = [paths[i].first, paths[i].last];
          solution[colorId] = List<int>.from(paths[i]);
        }
        return GameLevel(
          levelNumber: levelNumber,
          gridSize: n,
          dots: dots,
          solution: solution,
        );
      }
    }

    final fallbackDots = <int, List<int>>{};
    final fallbackSolution = <int, List<int>>{};
    for (int i = 0; i < numColors; i++) {
      final colorId = i + 1;
      final row = (i * n) ~/ numColors;
      final p = List<int>.generate(n, (col) => row * n + col);
      fallbackDots[colorId] = [p.first, p.last];
      fallbackSolution[colorId] = p;
    }
    return GameLevel(
      levelNumber: levelNumber,
      gridSize: n,
      dots: fallbackDots,
      solution: fallbackSolution,
    );
  }
}
