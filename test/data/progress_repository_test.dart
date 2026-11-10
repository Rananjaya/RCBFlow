import 'package:flutter_test/flutter_test.dart';
import 'package:flow/data/repositories/progress_repository.dart';
import 'package:flow/domain/models/user_progress.dart';

import '../helpers/test_doubles.dart';

void main() {
  late InMemoryHiveService hive;
  late ProgressRepository repo;
  late int notifications;

  setUp(() {
    hive = InMemoryHiveService();
    repo = ProgressRepository(hiveService: hive);
    notifications = 0;
    repo.addListener(() => notifications++);
  });

  test('getProgress loads once and then serves the cache', () async {
    hive.progress = const UserProgress(currentLevel: 3);
    expect((await repo.getProgress()).currentLevel, 3);

    hive.progress = const UserProgress(currentLevel: 99);
    expect((await repo.getProgress()).currentLevel, 3);
  });

  test(
    'completeLevel advances progress, records bests and clears save',
    () async {
      hive.progress = const UserProgress(currentLevel: 4).withSavedGame(
        levelNumber: 4,
        board: const [
          [1, 0, 1],
        ],
        moveCount: 3,
        elapsedSeconds: 20,
      );

      await repo.completeLevel(4, 11, 33);

      final p = hive.progress;
      expect(p.currentLevel, 5);
      expect(p.highestLevelCompleted, 4);
      expect(p.totalMoves, 11);
      expect(p.bestMoves[4], 11);
      expect(p.bestTimeSeconds[4], 33);
      expect(p.savedLevelNumber, isNull);
      expect(notifications, 1);
    },
  );

  test('completeLevel accumulates total moves across levels', () async {
    await repo.completeLevel(1, 5, 10);
    await repo.completeLevel(2, 7, 12);

    expect(hive.progress.totalMoves, 12);
    expect(hive.progress.currentLevel, 3);
    expect(hive.progress.highestLevelCompleted, 2);
  });

  test('saveCurrentBoard persists the in-progress game', () async {
    await repo.saveCurrentBoard(
      2,
      const [
        [1, 0, 1],
      ],
      4,
      15,
    );

    expect(hive.progress.savedLevelNumber, 2);
    expect(hive.progress.savedBoard, [
      [1, 0, 1],
    ]);
    expect(hive.progress.savedMoveCount, 4);
    expect(hive.progress.savedElapsedSeconds, 15);
    expect(notifications, 1);
  });

  test('resetProgress clears storage and the cache', () async {
    await repo.completeLevel(1, 5, 10);
    await repo.resetProgress();

    final p = await repo.getProgress();
    expect(p.currentLevel, 1);
    expect(p.highestLevelCompleted, 0);
    expect(p.bestMoves, isEmpty);
    expect(notifications, 2);
  });
}
