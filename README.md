<p align="center">
  <img src="assets/branding/rcbflow_logo_transparent.png" alt="RCBFlow logo" width="160" />
</p>

<h1 align="center">RCBFlow</h1>

<p align="center">
  A personal, independently branded fork of the open-source
  <a href="https://github.com/sidhant947/Flow">Flow</a> puzzle game.<br />
  Same connect-the-colours gameplay, with its own branding and a test suite.
</p>

<p align="center">
  <a href="https://flutter.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white" /></a>
  <a href="https://dart.dev"><img alt="Dart" src="https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart&logoColor=white" /></a>
  <img alt="Android 7.0+" src="https://img.shields.io/badge/Android-7.0%2B-3DDC84?logo=android&logoColor=white" />
  <a href="LICENSE"><img alt="License: GPL-3.0" src="https://img.shields.io/badge/License-GPL--3.0-blue" /></a>
  <a href="https://github.com/Rananjaya/RCBFlow"><img alt="GitHub repository" src="https://img.shields.io/badge/GitHub-Rananjaya%2FRCBFlow-181717?logo=github" /></a>
</p>

## About

RCBFlow is a logic puzzle: draw pipes to join dots of the same colour, without
crossing, until every cell on the board is filled. It runs fully offline and
keeps your progress on the device.

It is based on [Flow by sidhant947](https://github.com/sidhant947/Flow). The
gameplay comes from that project. This fork adds its own branding, privacy
cleanups and automated tests. RCBFlow is a personal project, maintained
independently, and is not affiliated with or endorsed by the original author.

## Screenshots

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/home.png" alt="RCBFlow home screen" width="200" /><br /><sub>Home</sub></td>
    <td align="center"><img src="docs/screenshots/gameplay.png" alt="RCBFlow gameplay with pipes drawn on the board" width="200" /><br /><sub>Gameplay</sub></td>
    <td align="center"><img src="docs/screenshots/levels.png" alt="RCBFlow level selection" width="200" /><br /><sub>Levels</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/settings.png" alt="RCBFlow settings" width="200" /><br /><sub>Settings</sub></td>
    <td align="center"><img src="docs/screenshots/how-to-play.png" alt="RCBFlow how to play" width="200" /><br /><sub>How to Play</sub></td>
    <td></td>
  </tr>
</table>

## Features

- Connect matching coloured dots; crossing an existing pipe cuts it.
- Level progression from 5×5 up to 14×14 boards, with levels unlocked as you go.
- Random mode with five difficulties (Easy to Master).
- Undo, clear, restart, move counter and timer.
- Optional hints that reveal one pipe from the solution.
- Progress, best moves/times and unfinished boards saved locally.
- Light, dark and system themes; sound effects toggle.
- Works offline. The release build requests no internet permission.

## Technology

[Flutter](https://flutter.dev) and Dart, targeting Android. State is managed with
[Riverpod](https://riverpod.dev) and stored locally with [Hive](https://pub.dev/packages/hive).

## Build and run

```bash
flutter pub get              # install dependencies
flutter analyze              # static analysis
flutter test                 # run the test suite
flutter run                  # run on a connected device or emulator
flutter build apk --debug    # debug APK
flutter build apk --release  # release APK
```

APKs are written to `build/app/outputs/flutter-apk/`. For details, see:

- [DEVELOPMENT.md](DEVELOPMENT.md): setup, architecture and project layout
- [TESTING.md](TESTING.md): how the tests are organised
- [RELEASE.md](RELEASE.md): versioning, signing and release checklist
- [PRIVACY_AND_SECURITY.md](PRIVACY_AND_SECURITY.md): data handling and rules for new features

## Credits

- **Original project:** [Flow](https://github.com/sidhant947/Flow) by
  [sidhant947](https://github.com/sidhant947). The gameplay, level generator,
  UI and sound effects come from that project, which remains the work of its
  author. Upstream AI-use declaration: [AI-DECLARATION.md](AI-DECLARATION.md).
- **This fork:** [Rananjaya/RCBFlow](https://github.com/Rananjaya/RCBFlow).
- **Logo:** generated using ChatGPT for this project. See
  [RELEASE.md](RELEASE.md#logo).
- **Sound effects:** inherited from upstream. Their licences haven't been
  verified yet. See [RELEASE.md](RELEASE.md#sound-effects).

**Modifications in this fork (November 2026):**

- New app name and Android application ID (`com.rananjaya.RCBFlow`).
- RCBFlow logo, launcher icon and home screen title.
- App version shown on the home screen.
- The star button links to this repository.
- Donation links to the original author's Ko-fi and Liberapay pages removed from
  the app, and the upstream `FUNDING.yml` removed from this repository.
- Store listing metadata updated with RCBFlow text, icon and screenshots.
- Local builds no longer need the upstream signing secrets.
- An automated test suite, a CI workflow, and tests before release builds.
- Project documentation.

## License

RCBFlow is licensed under the **GNU General Public License v3.0**, the same
licence as the original Flow project. See [LICENSE](LICENSE). Third-party
packages and bundled assets keep their own licences. See
[RELEASE.md](RELEASE.md#licensing-and-third-party-components) for what has been
reviewed and what still needs checking.
