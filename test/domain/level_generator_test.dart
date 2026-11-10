import 'package:flutter_test/flutter_test.dart';
import 'package:flow/domain/models/game_level.dart';
import 'package:flow/domain/use_cases/flow_rules.dart';
import 'package:flow/domain/use_cases/level_generator.dart';

/// Checks that a generated level is a valid, solvable Flow puzzle.
void expectValidPuzzle(GameLevel level) {
  final n = level.gridSize;
  final covered = <int>{};

  expect(level.solution.keys, unorderedEquals(level.dots.keys));
  for (final color in level.dots.keys) {
    final dots = level.dots[color]!;
    final path = level.solution[color]!;

    expect(dots, hasLength(2), reason: 'colour $color has two endpoints');
    expect(path.length, greaterThanOrEqualTo(2));
    expect({path.first, path.last}, {dots[0], dots[1]});
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1], b = path[i];
      final manhattan = ((a ~/ n) - (b ~/ n)).abs() + ((a % n) - (b % n)).abs();
      expect(manhattan, 1, reason: 'colour $color steps $a -> $b');
    }
    for (final cell in path) {
      expect(covered.add(cell), isTrue, reason: 'cell $cell used twice');
    }
  }
  expect(covered.length, level.totalCells, reason: 'solution fills the grid');
  expect(FlowRules.isComplete(level.solution, level), isTrue);
}

void main() {
  group('LevelGenerator.generateRandom', () {
    test('same seed produces the same puzzle', () {
      final a = LevelGenerator().generateRandom(gridSize: 6, seed: 2024);
      final b = LevelGenerator().generateRandom(gridSize: 6, seed: 2024);

      expect(a.dots, b.dots);
      expect(a.solution, b.solution);
    });

    test('different seeds produce different puzzles', () {
      final a = LevelGenerator().generateRandom(gridSize: 7, seed: 1);
      final b = LevelGenerator().generateRandom(gridSize: 7, seed: 2);

      expect(a.dots, isNot(equals(b.dots)));
    });

    for (final size in [5, 7, 9]) {
      test('${size}x$size puzzles are valid and fully solvable', () {
        for (var seed = 0; seed < 5; seed++) {
          final level = LevelGenerator().generateRandom(
            gridSize: size,
            seed: seed,
          );
          expect(level.gridSize, size);
          expect(level.levelNumber, -1);
          expectValidPuzzle(level);
        }
      });
    }
  });

  group('LevelGenerator.generate (campaign levels)', () {
    test('levels are deterministic for a given level number', () {
      final a = LevelGenerator().generate(12);
      final b = LevelGenerator().generate(12);

      expect(a.levelNumber, 12);
      expect(a.dots, b.dots);
      expect(a.solution, b.solution);
    });

    test('grid size grows every 25 levels', () {
      final generator = LevelGenerator();
      expect(generator.generate(1).gridSize, 5);
      expect(generator.generate(25).gridSize, 5);
      expect(generator.generate(26).gridSize, 6);
      expect(generator.generate(51).gridSize, 7);
    });

    test('early levels are valid and solvable', () {
      for (final n in [1, 2, 10, 25, 26]) {
        expectValidPuzzle(LevelGenerator().generate(n));
      }
    });
  });
}
