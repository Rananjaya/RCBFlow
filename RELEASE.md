# Releasing RCBFlow

How to version, build, sign, verify and publish an RCBFlow APK.

> **Never commit or share signing secrets.** `android/key.properties`, `*.jks`
> and `*.keystore` are already in `android/.gitignore`. Keep the keystore and its
> passwords in a password manager, with an offline backup.

## Versioning

The version is set in one place, `pubspec.yaml`:

```yaml
version: 1.0.0+1   # <versionName>+<versionCode>
```

| Part | Becomes | Rule |
|---|---|---|
| `1.0.0` | Android `versionName`, shown as "Version 1.0.0 (1)" on the home screen | Semantic version, chosen by the maintainer |
| `+1` | Android `versionCode` | **Must increase on every release.** Android won't install an update with an equal or lower code. |

You can override both for a single build with
`flutter build apk --build-name=1.1.0 --build-number=2`, but update
`pubspec.yaml` too so the repository records the real version.

**Split-ABI builds** (`--split-per-abi`, used by the upstream CI) multiply the
code: each APK gets `versionCode * 10 + abi`, where armeabi-v7a=1, arm64-v8a=2
and x86_64=3. The home screen then shows that number, for example "(12)".

## Building

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug                    # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release                  # build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release --split-per-abi  # smaller per-architecture APKs
```

Debug APKs are large (~110 MB), unoptimised and include the `INTERNET`
permission for development tools. Only distribute release APKs.

## Release signing

Android identifies an app by its **application ID plus its signing
certificate**. An update installs only if it is signed with the same key as the
app already on the device.

**Current state (verified 2026-11-10):** `android/key.properties` doesn't exist,
so `android/app/build.gradle.kts` signs release builds with the **Android debug
key** (`CN=Android Debug`). That keeps local builds working, but it is **not
suitable for a permanent release**:

- **It isn't stable.** The debug keystore is created per machine
  (`~/.android/debug.keystore`). A build from another computer, or after that
  file is deleted, is signed with a different key and **can't update** the
  installed app.
- **It isn't secret.** The debug keystore uses a well-known password, so anyone
  can produce APKs with an equally "valid" debug signature.
- **Changing keys later is costly.** Moving users from a debug-signed APK to a
  release-signed one means **uninstalling first**, and that **erases their local
  progress**. Pick a permanent key before sharing the app widely.

### Create a release keystore (once)

```bash
keytool -genkey -v \
  -keystore ~/keys/rcbflow-release.jks \
  -storetype JKS -keyalg RSA -keysize 4096 -validity 10000 \
  -alias rcbflow
```

Store the keystore **outside the repository** and keep a backup. If you lose it,
you can never publish another update under the same identity.

### Configure `android/key.properties`

Create `android/key.properties` (it is git-ignored). Use your own values; the
ones below are placeholders:

```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=rcbflow
storeFile=/absolute/path/to/rcbflow-release.jks
```

`storeFile` is resolved from `android/app/`, so either use an absolute path or a
path relative to that folder. Once this file exists, release builds use the key
automatically. If a field is missing, Gradle fails with
`null cannot be cast to non-null type kotlin.String`.

For GitHub Actions, the upstream workflows expect the secrets
`KEYSTORE_BASE64`, `STORE_PASSWORD`, `KEY_PASSWORD` and `KEY_ALIAS`.

## Verifying an APK

Use the newest version folder under `$ANDROID_HOME/build-tools/`:

```bash
BT=$ANDROID_HOME/build-tools/36.0.0
APK=build/app/outputs/flutter-apk/app-release.apk

$BT/aapt2 dump badging $APK | grep -E "^package:|application-label:|uses-permission"
# expect: package name='com.rananjaya.RCBFlow', label 'RCBFlow',
#         and no android.permission.INTERNET

$BT/apksigner verify --print-certs $APK
# expect: your release certificate, not "CN=Android Debug"
```

Write down the certificate's SHA-256 digest for each release. It must stay the
same across releases.

## Installation and upgrade testing

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk   # upgrade in place
adb shell dumpsys package com.rananjaya.RCBFlow | grep -E "versionName|versionCode"
```

1. Install the **previous** release and play a few levels, so there is saved
   progress and an unfinished board.
2. Install the new APK over it with `adb install -r`. Confirm that progress,
   settings and the unfinished board are still there.
3. Launch from the launcher. Check the icon, the name "RCBFlow", and the version
   under Settings on the home screen.
4. Check the log for crashes: `adb logcat | grep -E "FATAL EXCEPTION|E/flutter"`.

`INSTALL_FAILED_UPDATE_INCOMPATIBLE` means the signing key changed. Don't fix it
by uninstalling on users' devices; that erases their data. Rebuild with the
correct key instead.

## Release checklist

- [ ] `version:` bumped in `pubspec.yaml` (code higher than the last release)
- [ ] `flutter analyze` clean and `flutter test` passing
- [ ] Release APK built with the **release keystore**; `apksigner` shows the expected certificate
- [ ] Application ID is `com.rananjaya.RCBFlow` and the label is `RCBFlow`
- [ ] Permissions unchanged from the last release (or changes documented in [PRIVACY_AND_SECURITY.md](PRIVACY_AND_SECURITY.md))
- [ ] Upgrade over the previous release keeps progress and settings
- [ ] Smoke test on a device or emulator: home, a level, levels list, settings, how to play
- [ ] Release notes written; source for this exact version pushed and tagged (GPL-3.0 requires the source to be available)

## Licensing and third-party components

**RCBFlow code:** GPL-3.0, inherited from upstream Flow (see [LICENSE](LICENSE)).

**Upstream facts (checked 2026-11-10):**

- The upstream `LICENSE` is the unmodified GPL-3.0 text. Its "Copyright (C)
  <year> <name of author>" line isn't filled in, and the upstream repository has
  no other copyright notice.
- The upstream author is [sidhant947](https://github.com/sidhant947).
- The upstream has one commit, "Initial Release" (`6d7ab63`), and one release,
  V1.0.0.

**Obligations when distributing a modified version:**

- **Keep the licence:** ship or link the GPL-3.0 text.
- **Mark changes:** state that the work was modified, with a date
  (section 5(a)). The README's *Modifications in this fork* section serves this
  purpose.
- **Credit the original:** keep the attribution to the original project.
- **Provide source:** make the complete source for each distributed APK
  available (section 6). Publishing the tagged source on GitHub covers this.

| Component | Licence | Status |
|---|---|---|
| `flutter_riverpod` 2.6.1, `riverpod` | MIT | Verified (package LICENSE) |
| `hive` 2.2.3, `hive_flutter` 1.1.0 | Apache-2.0 | Verified |
| `url_launcher` 6.3.3 | BSD-3-Clause | Verified |
| `audioplayers` 6.8.1 | MIT | Verified |
| `package_info_plus` 10.2.2 | BSD-3-Clause | Verified |
| `cupertino_icons` 1.0.9 | MIT | Verified |
| Flutter engine/framework and transitive packages | Mostly BSD, MIT, Apache-2.0 | Flutter bundles their notices automatically (`assets/flutter_assets/NOTICES.Z` in the APK) |
| `assets/audio/*.mp3` (3 sound effects, from upstream) | **Unverified** | Kept by maintainer decision; investigate before public distribution. See [Sound effects](#sound-effects) |
| `assets/branding/rcbflow_icon.png` and derived files (logo, launcher icons, store icon) | Designed by Rananjaya for RCBFlow | No separate licence stated; see [Logo](#logo) |
| `fastlane/metadata/` text and images | Upstream text with RCBFlow edits; RCBFlow icon and screenshots | Only used for future store listings; see [Store metadata](#store-metadata) |

All the dependency licences listed are compatible with distribution under
GPL-3.0.

### Sound effects

**Files:**

- `assets/audio/sound.mp3`: 0.10 s, the drag step.
- `assets/audio/complete_connection.mp3`: 0.47 s, plays when a pipe connects.
- `assets/audio/level_complete.mp3`: 1.2 s, plays when a level is solved.

**Verified (2026-11-10):**

- **No credit anywhere upstream.** No source, author or licence is given in the
  upstream README, `AI-DECLARATION.md`, issues (none), pull requests (none) or
  F-Droid listing. F-Droid lists the app as GPL-3.0-only, with no anti-features
  and no audio credit.
- **No usable history.** The files arrived in upstream's single commit, so Git
  history can't show where they came from.
- **No embedded metadata.** All three were encoded with FFmpeg (`Lavf62.12.103`
  / `Lavc62.28`), and all other metadata (title, artist, copyright) is empty.

**Not verified:**

- whether the upstream author made these sounds, generated them, or took them
  from a sound library;
- what licence they are under.

The project's GPL-3.0 licence only covers them if the author had the right to
license them that way, and that can't be confirmed.

**Decision (maintainer, 2026-11-10):** keep all three sounds unchanged for now.
Their licences remain **unverified**.

**Before any public distribution** (store listing or public release APKs),
investigate them. Either:

1. ask the upstream author where the sounds came from, for example in a GitHub
   issue on `sidhant947/Flow`; or
2. replace them with sounds that have a clear licence (for example CC0) and
   record their source in this file.

Removing them without replacements would silence the game, unless the playback
code in `lib/data/services/sound_service.dart` is also removed.

### Logo

The RCBFlow logo (`assets/branding/rcbflow_icon.png`) was designed by
[Rananjaya](https://github.com/Rananjaya) for this project.

Everything else is derived from that image by this project:

- `rcbflow_logo_transparent.png` comes from
  `tool/branding/make_transparent_logo.py`, which only makes the black
  background transparent;
- the launcher icons come from `flutter_launcher_icons`;
- the 512×512 store icon (`fastlane/.../images/icon.png`) is a resized copy of
  the transparent logo.

No upstream or third-party artwork is involved. The logo has no licence of its
own, separate from the project's GPL-3.0 licence.

### Store metadata

`fastlane/metadata/android/en-US/` is only read by store tooling, such as
F-Droid when it builds from a repository. It doesn't affect the app.

| File | Content |
|---|---|
| `title.txt` | `RCBFlow: Connect Dots Puzzle` |
| `short_description.txt` | "Offline connect-the-dots colour puzzle. A fork of the Flow game." |
| `full_description.txt` | Upstream description, plus a statement that RCBFlow is an independent fork of Flow by sidhant947 under GPL-3.0, with a source link |
| `images/icon.png` | RCBFlow logo, 512×512 |
| `images/phoneScreenshots/1–5.png` | Copies of `docs/screenshots/`: home, gameplay, levels, how to play, settings (540×1212) |

The upstream description says "thousands of free stages". That holds: campaign
levels are generated for any level number, and Next Level keeps going without
limit.

Nothing has been submitted to any store.
