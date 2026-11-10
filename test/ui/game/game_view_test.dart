import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow/domain/models/user_progress.dart';
import 'package:flow/ui/core/widgets/flow_board_widget.dart';
import 'package:flow/ui/features/game/views/game_view.dart';
import 'package:flow/ui/providers.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_doubles.dart';

Future<TestApp> pumpGame(
  WidgetTester tester, {
  int level = 1,
  UserProgress progress = const UserProgress(),
}) async {
  setScreenSize(tester, const Size(411, 891));
  final app = TestApp(hive: InMemoryHiveService(progress));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hiveServiceProvider.overrideWithValue(app.hive),
        settingsServiceProvider.overrideWithValue(app.settings),
        soundServiceProvider.overrideWithValue(app.sound),
        levelGeneratorProvider.overrideWithValue(app.levelGenerator),
      ],
      child: MaterialApp(home: GameView(levelNumber: level)),
    ),
  );
  await tester.pump(); // run the initState microtask that loads the level
  await tester.pump();
  return app;
}

void main() {
  testWidgets('game screen initialises with the level, board and stats', (
    tester,
  ) async {
    final app = await pumpGame(tester, level: 6);

    expect(app.levelGenerator.requestedLevels, [6]);
    expect(find.text('Level 6'), findsOneWidget);
    expect(find.byType(FlowGameBoard), findsOneWidget);
    expect(find.text('Moves'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await unmountApp(tester);
  });

  testWidgets('on-screen timer ticks once per second', (tester) async {
    await pumpGame(tester);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01'), findsOneWidget);
    await tester.pump(const Duration(seconds: 64));
    expect(find.text('01:05'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('resumes a saved game with its moves and time', (tester) async {
    await pumpGame(
      tester,
      level: 2,
      progress: const UserProgress(
        currentLevel: 2,
        savedLevelNumber: 2,
        savedBoard: [
          [1, 0, 1],
        ],
        savedMoveCount: 5,
        savedElapsedSeconds: 90,
      ),
    );

    expect(find.text('01:30'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);

    await unmountApp(tester);
  });

  testWidgets('level-complete bar offers Next Level and Home only '
      '(no donation button)', (tester) async {
    final app = await pumpGame(tester, level: 1);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameView)),
    );
    final game = container.read(gameViewModelProvider.notifier);

    // Solve the 3x3 test level: three horizontal flows.
    for (final row in const [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
    ]) {
      game.startDrag(row.first);
      for (final cell in row.skip(1)) {
        game.dragStep(cell);
      }
      game.endDrag();
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(container.read(gameViewModelProvider).isComplete, isTrue);
    expect(app.hive.progress.currentLevel, 2);
    expect(find.text('Congratulations!'), findsOneWidget);
    expect(find.text('Next Level'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Buy me a Coffee'), findsNothing);
    expect(tester.takeException(), isNull);

    await unmountApp(tester);
  });
}
