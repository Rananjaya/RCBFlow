import 'package:flutter_test/flutter_test.dart';
import 'package:flow/data/repositories/progress_repository.dart';
import 'package:flow/domain/models/user_progress.dart';
import 'package:flow/ui/features/game/view_models/game_view_model.dart';

import '../../helpers/test_doubles.dart';

/// Builds a [GameViewModel] wired to in-memory doubles.
class _Harness {
  _Harness({UserProgress progress = const UserProgress()})
    : hive = InMemoryHiveService(progress) {
    repository = ProgressRepository(hiveService: hive);
    vm = GameViewModel(
      progressRepository: repository,
      levelGenerator: generator,
      settingsService: InMemorySettingsService(),
      soundService: sound,
    );
  }

  final InMemoryHiveService hive;
  final generator = FakeLevelGenerator();
  final sound = FakeSoundService();
  late final ProgressRepository repository;
  late final GameViewModel vm;

  GameViewModelState get state => vm.state;

  /// Draws a path for the flow starting at [cells.first].
  void draw(List<int> cells) {
    vm.startDrag(cells.first);
    for (final cell in cells.skip(1)) {
      vm.dragStep(cell);
    }
    vm.endDrag();
  }

  void solveAll() {
    draw([0, 1, 2]);
    draw([3, 4, 5]);
    draw([6, 7, 8]);
  }
}

// testWidgets is used throughout for its fake clock, which drives the game
// timer deterministically. Each test disposes the view model so the periodic
// timer never outlives the test.
void main() {
  group('Game initialisation and level loading', () {
    testWidgets('loadLevel loads the requested level with a fresh board', (
      tester,
    ) async {
      final h = _Harness();
      await h.vm.loadLevel(3);

      expect(h.generator.requestedLevels, [3]);
      expect(h.state.isLoading, isFalse);
      expect(h.state.error, isNull);
      expect(h.state.level!.levelNumber, 3);
      expect(h.state.level!.gridSize, 3);
      expect(h.state.paths, isEmpty);
      expect(h.state.moveCount, 0);
      expect(h.state.elapsedSeconds, 0);
      expect(h.state.isComplete, isFalse);
      expect(h.state.connectedCount, 0);
      h.vm.dispose();
    });

    testWidgets('restores a saved in-progress board for the same level', (
      tester,
    ) async {
      final h = _Harness(
        progress: const UserProgress(
          currentLevel: 5,
          savedLevelNumber: 5,
          savedBoard: [
            [1, 0, 1],
            [2, 3, 4, 5],
          ],
          savedMoveCount: 7,
          savedElapsedSeconds: 42,
        ),
      );
      await h.vm.loadLevel(5);

      expect(h.state.paths, {
        1: [0, 1],
        2: [3, 4, 5],
      });
      expect(h.state.moveCount, 7);
      expect(h.state.elapsedSeconds, 42);
      expect(h.state.connectedCount, 1);
      h.vm.dispose();
    });

    testWidgets('ignores a saved board that belongs to another level', (
      tester,
    ) async {
      final h = _Harness(
        progress: const UserProgress(
          savedLevelNumber: 9,
          savedBoard: [
            [1, 0, 1, 2],
          ],
          savedMoveCount: 3,
          savedElapsedSeconds: 10,
        ),
      );
      await h.vm.loadLevel(1);

      expect(h.state.paths, isEmpty);
      expect(h.state.moveCount, 0);
      expect(h.state.elapsedSeconds, 0);
      h.vm.dispose();
    });

    testWidgets('random mode maps difficulty to grid size', (tester) async {
      final h = _Harness();
      await h.vm.loadRandomLevel('Expert', seed: 1234);

      expect(h.generator.requestedRandom.single, {
        'gridSize': 12,
        'seed': 1234,
      });
      expect(h.state.isRandomMode, isTrue);
      expect(h.state.randomDifficulty, 'Expert');
      expect(h.state.randomSeed, 1234);
      expect(h.state.level, isNotNull);
      h.vm.dispose();
    });
  });

  group('Timer', () {
    testWidgets('counts elapsed seconds while playing', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);

      await tester.pump(const Duration(seconds: 3));
      expect(h.state.elapsedSeconds, 3);

      await tester.pump(const Duration(milliseconds: 999));
      expect(h.state.elapsedSeconds, 3);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.state.elapsedSeconds, 4);
      h.vm.dispose();
    });

    testWidgets('resumes from the saved elapsed time', (tester) async {
      final h = _Harness(
        progress: const UserProgress(
          savedLevelNumber: 1,
          savedBoard: [
            [1, 0, 1],
          ],
          savedElapsedSeconds: 60,
        ),
      );
      await h.vm.loadLevel(1);
      await tester.pump(const Duration(seconds: 2));

      expect(h.state.elapsedSeconds, 62);
      h.vm.dispose();
    });

    testWidgets('stops when the level is completed', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      await tester.pump(const Duration(seconds: 5));

      h.solveAll();
      await tester.pump();
      expect(h.state.isComplete, isTrue);
      final finalTime = h.state.elapsedSeconds;

      await tester.pump(const Duration(seconds: 10));
      expect(h.state.elapsedSeconds, finalTime);
      h.vm.dispose();
    });

    testWidgets('stops after the view model is disposed', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      h.vm.dispose();
      // Would throw "Timer is still pending" / mutate a disposed notifier if
      // the periodic timer were not cancelled.
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('Drawing flows', () {
    testWidgets('connecting both dots of a colour completes that flow', (
      tester,
    ) async {
      final h = _Harness();
      await h.vm.loadLevel(1);

      h.vm.startDrag(0);
      expect(h.state.activeColor, 1);
      h.vm.dragStep(1);
      h.vm.dragStep(2);

      expect(h.state.paths[1], [0, 1, 2]);
      expect(h.state.connectedCount, 1);
      expect(h.state.activeColor, isNull);
      expect(h.sound.events, contains('connection'));
      expect(h.state.isComplete, isFalse);
      h.vm.dispose();
    });

    testWidgets('cannot step onto another colour\'s dot or move diagonally', (
      tester,
    ) async {
      final h = _Harness();
      await h.vm.loadLevel(1);

      h.vm.startDrag(0);
      h.vm.dragStep(3); // dot of colour 2
      expect(h.state.paths[1], [0]);
      h.vm.dragStep(4); // diagonal
      expect(h.state.paths[1], [0]);
      h.vm.dispose();
    });

    testWidgets('dragging back over the path retracts it', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);

      h.vm.startDrag(3);
      h.vm.dragStep(4);
      expect(h.state.paths[2], [3, 4]);
      h.vm.dragStep(3);
      expect(h.state.paths[2], [3]);
      expect(h.sound.events.last, 'retract');
      h.vm.dispose();
    });

    testWidgets('crossing another flow cuts that flow', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      h.draw([3, 4]); // colour 2 partially drawn: 3 -> 4

      h.vm.startDrag(0);
      h.vm.dragStep(1);
      h.vm.dragStep(4); // cut colour 2 at cell 4

      expect(h.state.paths[1], [0, 1, 4]);
      expect(h.state.paths[2], [3]);
      h.vm.dispose();
    });

    testWidgets('each finished drag counts as a move', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);

      h.draw([3, 4]);
      h.draw([6, 7]);

      expect(h.state.moveCount, 2);
      h.vm.dispose();
    });

    testWidgets('undo restores the previous board', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      h.draw([3, 4]);
      h.draw([6, 7]);
      final movesBefore = h.state.moveCount;

      h.vm.undo();

      expect(h.state.paths, {
        2: [3, 4],
      });
      expect(h.state.moveCount, movesBefore + 1);
      h.vm.dispose();
    });

    testWidgets('clear board removes all paths', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      h.draw([3, 4]);

      h.vm.clearBoard();

      expect(h.state.paths, isEmpty);
      h.vm.dispose();
    });

    testWidgets('hint draws one unsolved flow from the solution, then fades', (
      tester,
    ) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      h.draw([0, 1, 2]); // colour 1 already solved

      h.vm.revealHint();

      expect(h.state.hintColor, 2);
      expect(h.state.paths[2], [3, 4, 5]);
      await tester.pump(const Duration(seconds: 3));
      expect(h.state.hintColor, isNull);
      expect(h.state.paths[2], [3, 4, 5]);
      h.vm.dispose();
    });
  });

  group('Game progress', () {
    testWidgets('an unfinished board is saved so it can be resumed', (
      tester,
    ) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      await tester.pump(const Duration(seconds: 4));

      h.draw([3, 4]);
      await tester.pump();

      final saved = h.hive.progress;
      expect(saved.savedLevelNumber, 1);
      expect(saved.savedBoard, [
        [2, 3, 4],
      ]);
      expect(saved.savedMoveCount, 1);
      expect(saved.savedElapsedSeconds, 4);
      h.vm.dispose();
    });

    testWidgets('completing a level unlocks the next one and records bests', (
      tester,
    ) async {
      final h = _Harness(progress: const UserProgress(currentLevel: 1));
      await h.vm.loadLevel(1);
      await tester.pump(const Duration(seconds: 7));

      h.solveAll();
      await tester.pump();

      expect(h.state.isComplete, isTrue);
      expect(h.sound.events, contains('level'));
      final p = h.hive.progress;
      expect(p.currentLevel, 2);
      expect(p.highestLevelCompleted, 1);
      expect(p.bestMoves[1], h.state.moveCount);
      expect(p.bestTimeSeconds[1], 7);
      expect(p.totalMoves, h.state.moveCount);
      // The in-progress save is cleared once the level is complete.
      expect(p.savedLevelNumber, isNull);
      expect(p.savedBoard, isNull);
      h.vm.dispose();
    });

    testWidgets('completion is recorded only once', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      h.solveAll();
      await tester.pump();
      final totalMoves = h.hive.progress.totalMoves;

      await h.vm.completeLevel(); // e.g. the view also calls this
      await tester.pump();

      expect(h.hive.progress.totalMoves, totalMoves);
      h.vm.dispose();
    });

    testWidgets('replaying an earlier level does not move progress backwards', (
      tester,
    ) async {
      final h = _Harness(
        progress: const UserProgress(
          currentLevel: 10,
          highestLevelCompleted: 9,
        ),
      );
      await h.vm.loadLevel(2);
      h.solveAll();
      await tester.pump();

      expect(h.hive.progress.currentLevel, 10);
      expect(h.hive.progress.highestLevelCompleted, 9);
      h.vm.dispose();
    });

    testWidgets('random games never change saved progress', (tester) async {
      final h = _Harness();
      await h.vm.loadRandomLevel('Easy', seed: 1);
      h.draw([3, 4]);
      h.solveAll();
      await tester.pump();

      expect(h.state.isComplete, isTrue);
      expect(h.hive.saveCount, 0);
      expect(h.hive.progress.currentLevel, 1);
      h.vm.dispose();
    });

    testWidgets('reset reloads the level from the saved state', (tester) async {
      final h = _Harness();
      await h.vm.loadLevel(1);
      h.draw([3, 4]);

      h.vm.resetLevel();
      await tester.pump();

      expect(h.generator.requestedLevels, [1, 1]);
      // The unfinished board was persisted, so reset restores it.
      expect(h.state.paths, {
        2: [3, 4],
      });
      h.vm.dispose();
    });
  });
}
