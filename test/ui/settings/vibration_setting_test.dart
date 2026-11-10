import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow/data/repositories/progress_repository.dart';
import 'package:flow/data/services/app_haptics.dart';
import 'package:flow/domain/models/app_settings.dart';
import 'package:flow/domain/models/user_progress.dart';
import 'package:flow/ui/features/game/view_models/game_view_model.dart';
import 'package:flow/ui/features/game/views/game_view.dart';
import 'package:flow/ui/features/settings/views/settings_view.dart';
import 'package:flow/ui/providers.dart';

import '../../helpers/haptics_recorder.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_doubles.dart';

Finder get _toggle => find.byKey(const Key('settings_vibration_toggle'));

void main() {
  final haptics = HapticsRecorder();

  setUp(() {
    mockPlatformVersion();
    AppHaptics.enabled = true;
    haptics.calls.clear();
  });
  tearDown(() {
    haptics.stop();
    AppHaptics.enabled = true;
  });

  Future<TestApp> openSettings(WidgetTester tester, {TestApp? app}) async {
    setScreenSize(tester, const Size(411, 891));
    final a = await pumpRcbFlowApp(tester, app: app);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsView), findsOneWidget);
    return a;
  }

  group('Settings screen', () {
    testWidgets('shows App Vibration with its description, ON by default', (
      tester,
    ) async {
      final app = await openSettings(tester);

      expect(find.text('App Vibration'), findsOneWidget);
      expect(
        find.text('Enable or disable vibration and haptic feedback.'),
        findsOneWidget,
      );
      expect(app.settings.settings.isVibrationEnabled, isTrue);
      expect(AppHaptics.enabled, isTrue);
      // Placed after Sound Effects, before Reset Progress.
      expect(
        tester.getTopLeft(_toggle).dy,
        greaterThan(tester.getTopLeft(find.text('Sound Effects')).dy),
      );
      expect(
        tester.getTopLeft(_toggle).dy,
        lessThan(tester.getTopLeft(find.text('Reset Progress')).dy),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('can be turned OFF and ON again; saved and applied each time', (
      tester,
    ) async {
      final app = await openSettings(tester);
      final savesBefore = app.settings.saveCount;

      await tester.tap(_toggle);
      await tester.pumpAndSettle();
      expect(app.settings.settings.isVibrationEnabled, isFalse);
      expect(AppHaptics.enabled, isFalse);
      expect(app.settings.saveCount, savesBefore + 1);

      await tester.tap(_toggle);
      await tester.pumpAndSettle();
      expect(app.settings.settings.isVibrationEnabled, isTrue);
      expect(AppHaptics.enabled, isTrue);
      expect(app.settings.saveCount, savesBefore + 2);
    });

    testWidgets('starts OFF when the saved setting is OFF', (tester) async {
      await openSettings(
        tester,
        app: TestApp(
          settings: InMemorySettingsService(
            const AppSettings(
              themeMode: ThemeMode.light,
              isVibrationEnabled: false,
            ),
          ),
        ),
      );
      expect(AppHaptics.enabled, isFalse);
    });

    testWidgets('toggling leaves other settings and game progress unchanged', (
      tester,
    ) async {
      const progress = UserProgress(currentLevel: 6, highestLevelCompleted: 5);
      final app = await openSettings(
        tester,
        app: TestApp(
          hive: InMemoryHiveService(progress),
          settings: InMemorySettingsService(
            const AppSettings(
              isHintEnabled: true,
              isSoundEnabled: false,
              themeMode: ThemeMode.light,
            ),
          ),
        ),
      );

      await tester.tap(_toggle);
      await tester.pumpAndSettle();

      final s = app.settings.settings;
      expect(s.isVibrationEnabled, isFalse);
      expect(s.isHintEnabled, isTrue);
      expect(s.isSoundEnabled, isFalse);
      expect(s.themeMode, ThemeMode.light);
      expect(app.hive.progress.currentLevel, 6);
      expect(app.hive.progress.highestLevelCompleted, 5);
      expect(app.hive.saveCount, 0);
    });
  });

  group('UI haptics follow the setting', () {
    testWidgets('ON: tapping buttons and options vibrates as before', (
      tester,
    ) async {
      await openSettings(tester);
      haptics.start();

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(haptics.calls, contains('HapticFeedbackType.selectionClick'));
    });

    testWidgets('OFF: no haptics from buttons, options, toggles or close', (
      tester,
    ) async {
      await openSettings(tester);
      await tester.tap(_toggle); // turn OFF
      await tester.pumpAndSettle();
      haptics.start();

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hints'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How to Play')); // TangibleButton on home
      await tester.pumpAndSettle();

      expect(haptics.calls, isEmpty);
    });
  });

  group('Game haptics follow the setting', () {
    GameViewModel newGame(FakeSoundService sound) => GameViewModel(
      progressRepository: ProgressRepository(
        hiveService: InMemoryHiveService(),
      ),
      levelGenerator: FakeLevelGenerator(),
      settingsService: InMemorySettingsService(),
      soundService: sound,
    );

    Future<void> playLevel(GameViewModel vm) async {
      await vm.loadLevel(1);
      for (final row in const [
        [0, 1, 2],
        [3, 4, 5],
        [6, 7, 8],
      ]) {
        vm.startDrag(row.first);
        for (final cell in row.skip(1)) {
          vm.dragStep(cell);
        }
        vm.endDrag();
      }
      // Backtracking (lightImpact) on a fresh level.
      await vm.loadLevel(2);
      vm.startDrag(3);
      vm.dragStep(4);
      vm.dragStep(3);
    }

    testWidgets('ON: drags, connections and backtracking vibrate as before', (
      tester,
    ) async {
      final vm = newGame(FakeSoundService());
      haptics.start();
      await playLevel(vm);
      vm.dispose();

      expect(haptics.calls, contains('HapticFeedbackType.selectionClick'));
      expect(haptics.calls, contains('HapticFeedbackType.mediumImpact'));
      expect(haptics.calls, contains('HapticFeedbackType.lightImpact'));
    });

    testWidgets('OFF: no game haptics; sounds and gameplay unaffected', (
      tester,
    ) async {
      AppHaptics.enabled = false;
      final sound = FakeSoundService();
      final vm = newGame(sound);
      haptics.start();
      await vm.loadLevel(1);
      vm.startDrag(0);
      vm.dragStep(1);
      vm.dragStep(2);
      vm.endDrag();
      await playLevel(vm);
      vm.dispose();

      expect(haptics.calls, isEmpty);
      expect(sound.events, containsAll(['step', 'connection', 'retract']));
    });

    // Vibration is set through the saved setting, which is what the app
    // reads when the screen opens.
    Future<void> completeLevelOnScreen(
      WidgetTester tester, {
      required bool vibration,
    }) async {
      setScreenSize(tester, const Size(411, 891));
      final app = TestApp(
        settings: InMemorySettingsService(
          AppSettings(
            themeMode: ThemeMode.light,
            isVibrationEnabled: vibration,
          ),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hiveServiceProvider.overrideWithValue(app.hive),
            settingsServiceProvider.overrideWithValue(app.settings),
            soundServiceProvider.overrideWithValue(app.sound),
            levelGeneratorProvider.overrideWithValue(app.levelGenerator),
          ],
          child: const MaterialApp(home: GameView(levelNumber: 1)),
        ),
      );
      await tester.pump();
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameView)),
      );
      final game = container.read(gameViewModelProvider.notifier);
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
      await unmountApp(tester);
    }

    testWidgets('ON: level completion gives the heavy impact', (tester) async {
      haptics.start();
      await completeLevelOnScreen(tester, vibration: true);
      expect(haptics.calls, contains('HapticFeedbackType.heavyImpact'));
    });

    testWidgets('OFF: level completion gives no vibration', (tester) async {
      haptics.start();
      await completeLevelOnScreen(tester, vibration: false);
      expect(AppHaptics.enabled, isFalse);
      expect(haptics.calls, isEmpty);
    });
  });
}
