# Testing RCBFlow

RCBFlow uses Flutter's standard test framework (`flutter_test`). The tests run on
the Dart VM without a device, network access or real platform plugins.

## Running tests

```bash
flutter test                                   # everything
flutter test test/ui/home                      # one folder
flutter test test/ui/navigation_test.dart      # one file
flutter test --name "timer"                    # tests whose name matches
flutter analyze                                # static analysis
```

**Current baseline:** 95 tests passing, plus a clean `flutter analyze`. This was
recorded on 2026-11-10 with Flutter 3.47.9 / Dart 3.13.7. The number will change
as tests are added; it isn't a fixed target.

> The GitHub Actions workflows don't run the tests (see
> [DEVELOPMENT.md](DEVELOPMENT.md#continuous-integration)). Run them locally
> before you push.

## Layout

```text
test/
  helpers/
    test_doubles.dart     In-memory fakes for storage, sound and level generation
    pump_app.dart         Pumps the real FlowApp with fakes; screen-size and version helpers
  domain/                 Pure logic: rules, generator, progress model
  data/                   Repository and real Hive persistence
  ui/
    home/                 Home screen layout, branding, links
    game/                 Game view model and game screen
    navigation_test.dart  Moving between screens
  version/                Version label and its source
```

| File | Tests | What it covers |
|---|---:|---|
| `ui/home/home_view_test.dart` | 13 | Logo asset, aspect ratio and centring; logo above the `RCBFlow` title; button order; version under Settings; level badge; no overflow at 6 screen sizes and large text |
| `ui/home/home_links_test.dart` | 6 | Star opens `https://github.com/Rananjaya/RCBFlow` externally; heart stays visible and launches nothing; no Ko-fi link |
| `ui/navigation_test.dart` | 7 | Play (at the saved level), back reloads progress, Settings (no donation button), Levels, How to Play, Random dialog and Cancel |
| `version/app_version_test.dart` | 7 | `Version X (N)` formatting; read from `package_info_plus`; matches `pubspec.yaml` |
| `ui/game/game_view_model_test.dart` | 22 | Loading and resuming levels, random mode, timer, drawing rules, undo/clear/hint, saving, completion and best scores |
| `ui/game/game_view_test.dart` | 4 | Game screen start-up, on-screen timer, resumed state, completion bar (Next Level / Home only) |
| `domain/flow_rules_test.dart` | 11 | Connection, completion, pipe percentage, legal steps (including no wrapping between rows) |
| `domain/level_generator_test.dart` | 8 | Same seed gives the same level; generated puzzles are valid and fully solvable; board size grows every 25 levels |
| `domain/user_progress_test.dart` | 5 | Best-result tracking, saved-game copying and clearing |
| `data/progress_repository_test.dart` | 5 | Caching, level completion, board saving, reset, listener notifications |
| `data/local_storage_test.dart` | 7 | Real Hive in a temp folder: settings and progress survive a simulated restart; legacy theme migration |

## Test doubles

These live in `test/helpers/test_doubles.dart`:

| Double | Replaces | Why |
|---|---|---|
| `InMemoryHiveService` | `HiveService` | Stores progress in memory; counts saves |
| `InMemorySettingsService` | `SettingsService` | Settings without Hive |
| `FakeSoundService` | `SoundService` | Records which sounds would play; no audio plugin |
| `FakeLevelGenerator` | `LevelGenerator` | Returns a fixed 3×3 level (`threeByThreeLevel`) immediately, with no isolates |

**Platform fakes:**

- `mockPlatformVersion()` uses `PackageInfo.setMockInitialValues` to stand in
  for Android's version name and code.
- `home_links_test.dart` installs a `RecordingUrlLauncher` as
  `UrlLauncherPlatform.instance`. It records URLs instead of opening a browser.
  This is url_launcher's recommended testing approach, and it needs the
  `url_launcher_platform_interface` and `plugin_platform_interface` dev
  dependencies.

**Overrides:** `pumpRcbFlowApp()` replaces the Riverpod providers with these
doubles and pumps the real `FlowApp`. Screen-level tests therefore exercise
production widgets, routing and view models.

## Patterns worth knowing

- **Time:** game view-model tests use `testWidgets` for its fake clock.
  `tester.pump(const Duration(seconds: 3))` advances the game timer
  deterministically.
- **Timers must not leak:** dispose the view model, or call `unmountApp(tester)`
  for screen tests, before a test ends. Otherwise Flutter reports a pending
  timer.
- **Screens with endless animation:** the game screen never "settles" because
  its timer keeps ticking. Use `pumpFor` or `tester.pump(duration)` instead of
  `pumpAndSettle()`.
- **Screen sizes:** `setScreenSize(tester, const Size(360, 640))` sets the
  logical size and resets it after the test.
- **Real persistence:** `local_storage_test.dart` calls `Hive.init(tempDir)` and
  closes and reopens the boxes to simulate an app restart.

## Adding tests

1. Put the test next to similar ones (`domain/`, `data/` or `ui/<feature>/`) and
   end the file name with `_test.dart`.
2. Prefer testing behaviour: what the user sees, or what gets saved. Checking
   that a widget exists is not enough.
3. Use the existing doubles. Add a new one to `test_doubles.dart` if a service
   touches a platform plugin, the file system or the network.
4. Make sure the test can fail: break the code temporarily and confirm the test
   goes red.
5. Run `dart format test` and `flutter analyze` before you commit.

## Limitations

- **No device tests.** There is no `integration_test/`. Everything runs on the
  Dart VM, so these need a manual check on a device or emulator:
  - real touch gestures on the board;
  - audio playback;
  - haptics;
  - opening the browser.
- **Board drags:** game tests drive `startDrag`, `dragStep` and `endDrag`
  directly rather than simulating pan gestures on `FlowGameBoard`.
- **Sound:** `SoundService` itself has no tests, because it needs the
  audioplayers plugin.
- **Visual checks:** there are no golden (pixel comparison) tests. The look of
  the app is checked by hand.
- **Background work:** level-generator tests for campaign levels start
  background pre-generation in isolates, which may still be running when the
  test finishes. This is harmless.
