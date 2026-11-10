import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow/domain/models/user_progress.dart';
import 'package:flow/ui/features/game/views/game_view.dart';
import 'package:flow/ui/features/home/views/home_view.dart';
import 'package:flow/ui/features/how_to_play/views/how_to_play_view.dart';
import 'package:flow/ui/features/level_select/views/level_select_view.dart';
import 'package:flow/ui/features/settings/views/settings_view.dart';

import '../helpers/pump_app.dart';
import '../helpers/test_doubles.dart';

/// Pumps frames for [duration] without waiting for infinite animations
/// (the game screen has a running timer, so pumpAndSettle never settles).
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < duration; t += step) {
    await tester.pump(step);
  }
}

void main() {
  setUp(mockPlatformVersion);

  Future<TestApp> pumpHome(WidgetTester tester, {UserProgress? progress}) {
    setScreenSize(tester, const Size(411, 891));
    return pumpRcbFlowApp(
      tester,
      app: TestApp(hive: InMemoryHiveService(progress ?? const UserProgress())),
    );
  }

  testWidgets('Play opens the game at the saved current level', (tester) async {
    final app = await pumpHome(
      tester,
      progress: const UserProgress(currentLevel: 4, highestLevelCompleted: 3),
    );

    await tester.tap(find.text('Play'));
    await pumpFor(tester, const Duration(milliseconds: 600));

    expect(find.byType(GameView), findsOneWidget);
    expect(tester.widget<GameView>(find.byType(GameView)).levelNumber, 4);
    expect(find.text('Level 4'), findsOneWidget);
    expect(find.text('Moves'), findsOneWidget);
    expect(app.levelGenerator.requestedLevels, contains(4));

    await unmountApp(tester);
  });

  testWidgets('back from the game returns home and reloads progress', (
    tester,
  ) async {
    final app = await pumpHome(tester);
    await tester.tap(find.text('Play'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.byType(GameView), findsOneWidget);

    // HomeViewModel.loadProgress() pre-generates levels around the current
    // one, so the fake generator's call count shows when home reloads.
    final reloadsBefore = app.levelGenerator.pregenerateRequests.length;
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await pumpFor(tester, const Duration(milliseconds: 600));

    expect(find.byType(GameView), findsNothing);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.byKey(const Key('home_logo')), findsOneWidget);
    expect(find.text('Play').hitTestable(), findsOneWidget);
    expect(
      app.levelGenerator.pregenerateRequests.length,
      greaterThan(reloadsBefore),
      reason: 'home reloads progress after the game route pops',
    );
  });

  testWidgets('Settings opens the settings screen and closes back to home', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Sound Effects'), findsOneWidget);
    expect(find.text('Reset Progress'), findsOneWidget);
    expect(find.text('Become a Backer'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsView), findsNothing);
    expect(find.byType(HomeView), findsOneWidget);
    expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
  });

  testWidgets('Levels opens level select', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Levels'));
    await tester.pumpAndSettle();

    expect(find.byType(LevelSelectView), findsOneWidget);
  });

  testWidgets('How to Play opens the rules screen', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('How to Play'));
    await tester.pumpAndSettle();

    expect(find.byType(HowToPlayView), findsOneWidget);
    expect(find.text('Goal'), findsOneWidget);
  });

  testWidgets('Random shows difficulties and starts a random game', (
    tester,
  ) async {
    final app = await pumpHome(tester);

    await tester.tap(find.text('Random'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Difficulty'), findsOneWidget);
    for (final d in ['Easy', 'Medium', 'Hard', 'Expert', 'Master']) {
      expect(find.text(d), findsOneWidget);
    }

    await tester.tap(find.text('Hard'));
    await pumpFor(tester, const Duration(milliseconds: 600));

    final game = tester.widget<GameView>(find.byType(GameView));
    expect(game.isRandom, isTrue);
    expect(game.randomDifficulty, 'Hard');
    expect(app.levelGenerator.requestedRandom.single['gridSize'], 9);

    await unmountApp(tester);
  });

  testWidgets('Random dialog Cancel keeps the user on home', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Random'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Difficulty'), findsNothing);
    expect(find.byType(GameView), findsNothing);
    expect(find.byType(HomeView), findsOneWidget);
  });
}
