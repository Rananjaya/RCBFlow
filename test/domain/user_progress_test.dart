import 'package:flutter_test/flutter_test.dart';
import 'package:flow/domain/models/user_progress.dart';

void main() {
  group('UserProgress.recordLevelResult', () {
    test('records the first result for a level', () {
      final p = const UserProgress().recordLevelResult(3, 12, 40);
      expect(p.bestMoves[3], 12);
      expect(p.bestTimeSeconds[3], 40);
    });

    test('keeps only improvements, independently for moves and time', () {
      final p = const UserProgress()
          .recordLevelResult(3, 12, 40)
          .recordLevelResult(3, 10, 55) // fewer moves, slower
          .recordLevelResult(3, 15, 30); // more moves, faster

      expect(p.bestMoves[3], 10);
      expect(p.bestTimeSeconds[3], 30);
    });

    test('does not mutate the original maps', () {
      const original = UserProgress();
      original.recordLevelResult(1, 5, 5);
      expect(original.bestMoves, isEmpty);
    });
  });

  group('UserProgress saved game', () {
    test('withSavedGame stores a defensive copy of the board', () {
      final board = [
        [1, 0, 1],
      ];
      final p = const UserProgress().withSavedGame(
        levelNumber: 4,
        board: board,
        moveCount: 2,
        elapsedSeconds: 9,
      );
      board.first.add(2);

      expect(p.savedLevelNumber, 4);
      expect(p.savedBoard, [
        [1, 0, 1],
      ]);
      expect(p.savedMoveCount, 2);
      expect(p.savedElapsedSeconds, 9);
    });

    test('withoutSavedGame clears the save but keeps progress', () {
      final p =
          const UserProgress(
                currentLevel: 6,
                highestLevelCompleted: 5,
                totalMoves: 50,
                bestMoves: {5: 8},
              )
              .withSavedGame(
                levelNumber: 6,
                board: const [
                  [1, 0],
                ],
                moveCount: 1,
                elapsedSeconds: 3,
              )
              .withoutSavedGame();

      expect(p.savedLevelNumber, isNull);
      expect(p.savedBoard, isNull);
      expect(p.savedMoveCount, 0);
      expect(p.savedElapsedSeconds, 0);
      expect(p.currentLevel, 6);
      expect(p.highestLevelCompleted, 5);
      expect(p.totalMoves, 50);
      expect(p.bestMoves, {5: 8});
    });
  });
}
