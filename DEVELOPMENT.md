# Developing RCBFlow

This guide explains how RCBFlow is put together and how to build and change it.
RCBFlow is a fork of [Flow](https://github.com/sidhant947/Flow). Most of the
architecture described here comes from that project.

## Requirements

| Tool | Version | Notes |
|---|---|---|
| Flutter | stable, 3.47.9 verified | Any stable release whose Dart satisfies `sdk: ^3.13.5` in `pubspec.yaml` |
| Dart | 3.13.7 (bundled with Flutter) | |
| JDK | 17 | `android/app/build.gradle.kts` compiles for Java 17 |
| Android SDK | compileSdk 36, build-tools 36 | Versions come from the Flutter Gradle plugin |
| Android NDK | 28.2.13676358 | Gradle installs it automatically on the first build if it is missing |
| Gradle / AGP / Kotlin | 9.3.1 / 9.1.0 / 2.4.0 | Wrapper and plugins pinned in `android/` |

Android support starts at **minSdk 24 (Android 7.0)**, and the app targets SDK 36.
Only Android is configured. The project has no `ios/`, `web/` or desktop folders.

`android/local.properties`, `android/gradlew` and `android/key.properties` are
not committed. Flutter creates the first two when you run `flutter pub get` or
`flutter build`.

## Project layout

```text
lib/
  main.dart                     App entry: opens Hive, loads settings, starts ProviderScope
  ui/providers.dart             All Riverpod providers (dependency wiring)
  domain/
    models/                     Immutable data: GameLevel, UserProgress, AppSettings, AppVersion
    use_cases/flow_rules.dart   Pure puzzle rules (connected, complete, legal step)
    use_cases/level_generator.dart  Deterministic level and random puzzle generation
  data/
    services/hive_service.dart      Progress box (Hive)
    services/user_progress_adapter.dart  Hive TypeAdapter for UserProgress
    services/settings_service.dart  Settings box (Hive)
    services/sound_service.dart     Sound effects (audioplayers)
    repositories/progress_repository.dart  Progress cache + business operations
  ui/
    core/theme/                 Colours and Material themes (light/dark)
    core/widgets/               FlowGameBoard (board + drag gestures), TangibleButton
    features/<screen>/views/    Screens: home, game, level_select, settings, how_to_play
    features/<screen>/view_models/  StateNotifiers for home, game, settings
assets/
  audio/                        Sound effects (from upstream)
  branding/rcbflow_icon.png     Official logo (source artwork, not bundled)
  branding/rcbflow_logo_transparent.png  Derived logo used in the app and launcher icon
tool/branding/make_transparent_logo.py   Regenerates the derived logo
tool/ci/                        CI helpers: version check, APK verification
android/                        Android host project (Gradle Kotlin DSL)
test/                           Automated tests (see TESTING.md)
docs/screenshots/               README screenshots
fastlane/metadata/              Store listing text, icon and screenshots (not yet published)
```

## Architecture

The code is split into three layers. Each layer only depends on the ones below it.

1. **Domain** (`lib/domain`): plain Dart with no Flutter widgets or storage.
   `FlowRules` decides whether a path connects two dots, whether a move is legal
   and whether the board is solved. `LevelGenerator` builds puzzles.
2. **Data** (`lib/data`): persistence and device services. `ProgressRepository`
   wraps `HiveService`, keeps an in-memory copy of progress, and notifies
   listeners when it changes.
3. **UI** (`lib/ui`): screens and view models, organised by feature.

### State management

The app uses [Riverpod 2](https://riverpod.dev) (`flutter_riverpod`), with every
provider declared in `lib/ui/providers.dart`:

- `hiveServiceProvider` and `settingsServiceProvider` are overridden in
  `main.dart` with instances that have already been initialised.
- `homeViewModelProvider`, `gameViewModelProvider` (auto-dispose) and
  `settingsProvider` are `StateNotifierProvider`s holding immutable state classes.
- `appVersionProvider` is a `FutureProvider` that reads the installed version
  through `package_info_plus`.

Tests replace these providers with in-memory fakes; see [TESTING.md](TESTING.md).

### Navigation

Navigation is imperative: screens are pushed with `Navigator.push` and
`MaterialPageRoute`. There is no named-route table or router package.
`HomeView` is the root. From there you can reach `GameView`, `LevelSelectView`,
the Random difficulty dialog (which opens `GameView` in random mode),
`HowToPlayView` and `SettingsView`. When a level is complete, **Next Level**
replaces the current game route and **Home** pops back to the home screen.

### Game logic

`GameViewModel` (`lib/ui/features/game/view_models/game_view_model.dart`) owns a
game session:

- **Drawing:** `startDrag`, `dragStep` and `endDrag` turn board gestures from
  `FlowGameBoard` into paths. Stepping onto another colour's dot or moving
  diagonally is rejected. Going back over your own path shortens it, and crossing
  another colour's pipe cuts that pipe.
- **Undo, clear, hint:** `undo` and `clearBoard` use a history of earlier boards.
  `revealHint` draws one unsolved flow from the stored solution and highlights it
  for 3 seconds. The hint button only appears when Hints is turned on in Settings.
- **Timer:** a one-second periodic timer. It stops when the level is complete
  or the view model is disposed.
- **Saving:** after each move an unfinished campaign board is saved, so it can
  be resumed later. Completing a level records the result once
  (`completeLevel`). Random games never touch saved progress.

### Level management

`LevelGenerator` produces each campaign level **deterministically** from its
number (seed `levelNumber * 10007 + 31`), so level N is the same on every device:

- **Board size:** grows by one every 25 levels, from 5×5 (levels 1–25) to 14×14
  (level 226 onwards).
- **Number of colours:** increases within each 25-level tier.
- **How a puzzle is built:** colour seeds are placed and grown into paths until
  the grid is full. If 300 attempts fail, a simple fallback layout of straight
  rows is used.
- **Performance:** generation runs in a background isolate via `compute`, and
  the next levels are generated ahead of time and cached.
- **Random mode:** uses a time-based seed. Easy, Medium, Hard, Expert and Master
  map to 5, 7, 9, 12 and 14-cell boards.

### Local storage

[Hive](https://pub.dev/packages/hive) boxes live in the app's private documents
directory (`Hive.initFlutter()` uses `getApplicationDocumentsDirectory()`):

| Box | Contents |
|---|---|
| `flow_user_progress` | One `UserProgress` record (key `progress`, adapter typeId 0): current/highest level, total moves, best moves/time per level, the saved unfinished board |
| `flow_settings` | `hint_enabled`, `sound_enabled`, `theme_mode` (older installs: `app_theme`, migrated on read) |

The box names and keys still use the upstream `flow_` prefix. Changing them would
silently reset players' progress.

### Assets and branding

- Assets declared in `pubspec.yaml`: `assets/audio/` and the transparent logo.
  The original logo file stays in the repository as the source artwork but isn't
  shipped in the app.
- **Launcher icons** are generated from the logo:

  ```bash
  python3 tool/branding/make_transparent_logo.py \
    assets/branding/rcbflow_icon.png assets/branding/rcbflow_logo_transparent.png
  dart run flutter_launcher_icons
  ```

  The `flutter_launcher_icons:` section of `pubspec.yaml` controls the output:

  - an adaptive icon with a white background;
  - a 20% inset, so the "RCBFlow" lettering stays inside the area every launcher
    shape shows;
  - legacy icons for older Android versions.

  There is no monochrome (themed) icon layer.
- **App name and version:** the name is set by `android:label` in
  `android/app/src/main/AndroidManifest.xml`. The version comes from `version:`
  in `pubspec.yaml`.

### Android configuration

`android/app/build.gradle.kts`:

- `namespace` / `applicationId`: `com.rananjaya.RCBFlow`. `MainActivity` lives at
  `android/app/src/main/kotlin/com/rananjaya/RCBFlow/MainActivity.kt`.
- **Release signing:** uses `android/key.properties` when that file exists, and
  otherwise falls back to the debug key (see [RELEASE.md](RELEASE.md)).
- **Split-ABI builds:** with `--split-per-abi`, each APK's version code becomes
  `versionCode * 10 + abi`, where abi is armeabi-v7a=1, arm64-v8a=2 or x86_64=3.
- `dependenciesInfo` is excluded from APKs and bundles.

The debug and profile manifests add `INTERNET` for Flutter tooling only. The
main (release) manifest has no internet permission.

## Common commands

```bash
flutter pub get                 # install dependencies
dart format lib test            # format code
flutter analyze                 # lints (analysis_options.yaml, flutter_lints)
flutter test                    # all tests
flutter run                     # debug run on a device/emulator
flutter build apk --debug
flutter build apk --release
flutter build apk --release --split-per-abi
```

## Continuous integration

There are two workflows, with Flutter pinned to 3.47.9 in both:

| Workflow | Runs on | Does |
|---|---|---|
| `.github/workflows/ci.yml` | Pull requests into `main`, pushes to `feature/**`, manual runs | Three jobs: **Analyze and test**, **Version check** and **Release build check**. No secrets, nothing published. |
| `.github/workflows/release.yml` | Pushes to `main` (merged pull requests) | Analyze, test, version check, signed build, APK verification, then tag `vX.Y.Z` and a GitHub Release with the APK and its SHA-256 |

**Helper scripts (they also work locally):**

- `tool/ci/check_version.sh` validates `version:` in `pubspec.yaml` against
  the release tags.
- `tool/ci/verify_apk.sh` checks an APK. `--mode structure` (PR builds) checks
  the package ID, version and permissions. `--mode release` also requires
  exactly one valid signer with the release certificate fingerprint. Its tests
  are in `tool/ci/tests/verify_apk_test.sh`.

Versioning rules, the signing secrets, branch protection and recovering from a
failed release are covered in [RELEASE.md](RELEASE.md).

## Troubleshooting

| Problem | Fix |
|---|---|
| `flutter.sdk not set in local.properties` | Run `flutter pub get` (creates `android/local.properties`) |
| `null cannot be cast to non-null type kotlin.String` in `build.gradle.kts` | `android/key.properties` exists but is missing a key; complete it or delete it |
| First build is very slow | Gradle is downloading itself, plugins and the NDK; later builds are cached |
| `WARNING: A restricted method in java.lang.System has been called` | Harmless Gradle/JDK warning |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | The installed app was signed with a different key; see [RELEASE.md](RELEASE.md#installation-and-upgrade-testing) |
| Launcher icon didn't change on the device | Launchers cache icons; reinstall the app or restart the launcher |
| Strange build state | `flutter clean && flutter pub get` |

## Contributing changes

- Keep gameplay rules in `FlowRules` and `GameViewModel`, and keep widgets thin.
- Add or update tests for behaviour you change ([TESTING.md](TESTING.md)).
- Follow [PRIVACY_AND_SECURITY.md](PRIVACY_AND_SECURITY.md) before adding a
  dependency, permission or network call.
- If you use AI assistance, say so; see the upstream
  [AI-DECLARATION.md](AI-DECLARATION.md).
