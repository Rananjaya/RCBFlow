# Releasing RCBFlow

How RCBFlow is versioned, validated, signed and published.

> **Never commit or share signing secrets.** These are git-ignored and must
> stay off GitHub: `android/key.properties`, `*.jks`, `*.keystore`, credential
> notes and APKs. CI only receives signing material through encrypted
> repository secrets.

## How a release happens

```text
feature branch ──► pull request into main
                     │  CI: Analyze and test · Version check · Release build check
                     ▼  (all required to pass; see "Branch protection")
                   merge
                     │
                     ▼  Release workflow (push to main)
   analyze → test → version check → signed build → verify APK
                     │  (any failure: nothing is published)
                     ▼
   tag vX.Y.Z  →  GitHub Release "RCBFlow X.Y.Z"
                  ├─ RCBFlow-X.Y.Z-release.apk
                  └─ RCBFlow-X.Y.Z-release.apk.sha256
```

Each merge into `main` publishes exactly one release, so **every pull request
into `main` must raise the version**, even one that only changes documentation.

## Versioning

`pubspec.yaml` is the single source of truth:

```yaml
version: 1.0.1+2   # MAJOR.MINOR.PATCH+BUILD
```

| Part | Becomes | Rule |
|---|---|---|
| `1.0.1` | Android `versionName`, Git tag `v1.0.1`, release title "RCBFlow 1.0.1", APK name `RCBFlow-1.0.1-release.apk`; shown on the home screen as "Version 1.0.1 (2)" | [Semantic versioning](https://semver.org); must be higher than the latest release tag |
| `+2` | Android `versionCode` | Must be higher than the build number of the latest release. Android won't install an update with an equal or lower code. |

### Choosing the version (your decision)

CI checks that the version went **up**. It doesn't decide *how much*; that's
your call when you open the pull request.

| Bump | When | Example |
|---|---|---|
| **MAJOR** (`1.4.2` → `2.0.0`) | A breaking change for players or the project | Saved progress can't be read after updating; minimum Android version raised; gameplay rules changed incompatibly |
| **MINOR** (`1.4.2` → `1.5.0`) | A backward-compatible feature | New game mode, new setting, new screen |
| **PATCH** (`1.4.2` → `1.4.3`) | A backward-compatible fix or small change | Bug fix, layout fix, documentation or CI-only change |

Always add 1 to the build number, whatever kind of bump it is. Reset MINOR and
PATCH to 0 when you bump MAJOR, and reset PATCH when you bump MINOR.

### Bumping the version

1. On your feature branch, edit the `version:` line in `pubspec.yaml`, for
   example `1.0.0+1` → `1.0.1+2`.
2. Commit it with your other changes and open the pull request.
3. **Version check** confirms the bump. To check locally first:

   ```bash
   git fetch --tags
   bash tool/ci/check_version.sh
   ```

**What the check enforces** (`tool/ci/check_version.sh`):

- **Format:** `MAJOR.MINOR.PATCH+BUILD`. No leading zeros, no pre-release
  suffix (`-beta`), and a build number from 1 to 2,100,000,000.
- **Higher version:** above the latest `vX.Y.Z` tag. Tags in other formats are
  ignored.
- **Higher build number:** above the build number in `pubspec.yaml` at that
  tag.
- **No duplicates:** the `vX.Y.Z` tag for this version mustn't exist yet.
- **First release:** if there are no release tags at all, any valid version is
  accepted. That will be `1.0.0+1`.

## Pull request validation

`.github/workflows/ci.yml` runs on every pull request into `main`, and on
pushes to `feature/**` branches. It runs three jobs:

| Check name | What it does |
|---|---|
| **Analyze and test** | `flutter pub get`, `flutter analyze`, `flutter test` |
| **Version check** | Runs `check_version.sh` against the tags (pull requests only) |
| **Release build check** | Builds the release APK (not release-signed, because PRs get no secrets) and checks it with `verify_apk.sh --mode structure`: package ID, version name and code, no INTERNET permission. Also runs the script's self-tests (`tool/ci/tests/verify_apk_test.sh`). |

**Security:**

- It uses the plain `pull_request` trigger and has read-only permissions.
- It has **no access to signing secrets**, so pull requests from forks can't
  reach the keystore.
- The release build check therefore uses the debug-key fallback. Its APK is
  only a compile check and is never uploaded.
- Flutter is pinned to the version the tests are verified with (`3.47.9`); see
  `FLUTTER_VERSION` in the workflows.

## Automatic releases

`.github/workflows/release.yml` runs on every push to `main`. With branch
protection on, that means every merged pull request. It runs only in
`Rananjaya/RCBFlow` on `main`, never on forks or feature branches.

1. Waits for any earlier release runs to finish, then checks out the exact
   merged commit, with full history and tags.
2. Runs `flutter analyze` and `flutter test` again.
3. Runs `check_version.sh --mode release`, and stops if a GitHub Release for the
   version already exists.
4. Decodes the keystore from secrets into the runner's temporary folder and
   writes `android/key.properties`.
5. Builds the signed universal APK with `flutter build apk --release`.
6. Runs `tool/ci/verify_apk.sh --mode release`:
   - the package is `com.rananjaya.RCBFlow`;
   - there's no INTERNET permission;
   - the versionName and versionCode match `pubspec.yaml`;
   - the signature verifies, with **exactly one** signer certificate;
   - that certificate's SHA-256 equals `RELEASE_CERT_SHA256` in the workflow.

   An unsigned APK, or one signed with any other key (including the debug key),
   fails here.
7. Copies the APK to `RCBFlow-X.Y.Z-release.apk` and writes a `.sha256` file.
8. Pushes tag `vX.Y.Z` on the merged commit. It never force-pushes, so an
   existing tag can't be moved.
9. Publishes the GitHub Release "RCBFlow X.Y.Z" with the APK and checksum. The
   notes are generated from the merged pull requests.
10. Deletes the keystore and `key.properties` from the runner, even if an
    earlier step failed.

**Safety rules:**

- **Permissions:** the workflow is read-only by default. Only the release job
  gets `contents: write`, to push the tag and create the release, and
  `actions: read`, to see earlier runs.
- **Every merge gets its own release, in merge order:** the job's first step
  waits until every earlier run of this workflow has finished (first in, first
  out, by run number). If several pull requests are merged quickly, each one is
  released in turn; none is skipped.
- **Why there's no `concurrency:` group:** GitHub keeps only one pending run per
  group and cancels older pending ones, which would skip versions. The wait
  gives up after 75 minutes with an error; re-run the job once the earlier runs
  finish.
- **No conflicting tags:** tags are pushed without `--force`, so a tag can never
  be overwritten, even if two runs somehow overlapped. The version check also
  rejects a version whose tag already exists.
- **Pinned actions:** only `actions/checkout`, `actions/setup-java` and
  `subosito/flutter-action` are used, each pinned to a commit SHA. Releases are
  published with the GitHub CLI that is preinstalled on the runner.

## Signing secrets

The release job needs four **repository secrets**. Set them under GitHub →
*Settings* → *Secrets and variables* → *Actions* → *New repository secret*.

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | The keystore file, base64-encoded (see below) |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password, from your password manager |
| `ANDROID_KEY_ALIAS` | `rcbflow-release` |
| `ANDROID_KEY_PASSWORD` | The **same** value as the keystore password. The keystore is PKCS12, which uses one password for both. |

**Encode the keystore without showing it on screen** (macOS):

```bash
base64 -i ~/.android/keystores/rcbflow-release.jks | pbcopy   # copies to clipboard
# paste into the ANDROID_KEYSTORE_BASE64 secret, then clear the clipboard:
pbcopy < /dev/null
```

**Passwords:** paste them directly from your password manager into the GitHub
secret form. Don't put them in shell commands, files in the repository, issues
or chat.

GitHub hides secret values in logs, and the workflow never prints them. If a
secret is missing, the release fails at *Set up release signing* and names the
missing secret. Nothing is published.

## Branch protection for `main`

Adding workflow files **doesn't** protect `main` by itself. Set it up in GitHub
under *Settings* → *Rules* → *Rulesets* → *New branch ruleset*, or the classic
*Settings* → *Branches* → *Add branch protection rule*:

- **Target:** `main` (default branch).
- **Require a pull request before merging.**
- **Require status checks to pass**, and select exactly:
  - `Analyze and test`
  - `Version check`
  - `Release build check`
- **Require branches to be up to date before merging** (recommended). This
  re-runs Version check against the latest tags, so two pull requests can't
  claim the same version.
- **Block force pushes** and **restrict deletions**.
- **Don't allow bypassing** the rules, or in classic rules, *Include
  administrators*. Then nobody can push directly to `main`, you included.

Status checks only appear in the picker after they have run at least once, so
open a pull request first.

If you later add **tag** rules, let GitHub Actions create `v*` tags, otherwise
the release job can't push them.

## Recovering from a failed release

Open the failed run under *Actions* → *Release*.

| Where it failed | What happened | What to do |
|---|---|---|
| Analyze, test, version check, build or APK verification | Nothing tagged or published | Fix it in a new pull request. The version wasn't released, so you can keep it. |
| *Set up release signing* | Secrets missing or wrong; nothing published | Fix the secrets, then **Re-run jobs** on the same run |
| *Publish GitHub Release*, with the tag already created | Tag exists, no release | **Re-run jobs.** The version check sees the tag on the same commit and resumes, skipping tag creation. |
| A release exists but is incomplete (e.g. missing an asset) | Re-runs refuse to overwrite it | Delete the incomplete release (not the tag) on the *Releases* page, then **Re-run jobs** |
| A bad build was released | — | Never reuse a version and never move a tag. Fix it, bump the version (e.g. PATCH) and merge. You can mark the bad release as a pre-release or delete it. |

## Building locally

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug     # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

- With `android/key.properties` present (git-ignored), local release builds are
  signed with the release key. Without it, `android/app/build.gradle.kts` falls
  back to the debug key. That's fine for testing, but never distribute such an
  APK.
- Debug APKs (~110 MB) include `INTERNET` for development tools. Only
  distribute release APKs.
- `--split-per-abi` builds multiply the versionCode (`versionCode * 10 + abi`).
  Releases ship the universal APK only.

## The permanent signing keystore

Android identifies an app by its **application ID plus its signing
certificate**. Updates only install if they are signed with the same key, so
this key must stay the same for the life of the app.

| | |
|---|---|
| Keystore | `~/.android/keystores/rcbflow-release.jks` (PKCS12, outside the repo) |
| Alias | `rcbflow-release` |
| Certificate | `CN=Rananjaya, O=RCBFlow`, RSA 4096, SHA256withRSA, valid until 2054-03-28 |
| SHA-256 | `5F:B9:6F:94:50:A5:31:66:48:CD:C4:13:48:83:E1:C2:B6:D3:F0:08:CA:32:BA:22:35:CF:F3:43:D3:BB:44:A2` |
| Encrypted backup | `~/RCBFlow-Backups/rcbflow-release-keystore-backup.dmg` (AES-256, separate passphrase). Keep a copy on offline external storage. |

**Keeping the keystore safe:**

- Keep the keystore password and the backup passphrase in a password manager.
- Never upload the keystore to the repository, as an artifact or to public cloud
  storage.
- Test the backup occasionally: mount the DMG and run `keytool -list` on the
  copy inside.
- **If the keystore or its password is lost**, no further update can be
  installed over existing installs. Users would have to uninstall, losing their
  progress, and install a new app identity.
- **If it may have leaked**, rotate the GitHub secrets immediately and get
  advice before replacing the key. Android key rotation (APK Signature Scheme
  v3.1) is possible but advanced.
- The certificate fingerprint is also recorded in `release.yml`
  (`RELEASE_CERT_SHA256`). Change it only if you deliberately rotate the key.

Earlier test builds were signed with the Android debug key. Devices with those
installs can't upgrade to a release-signed APK
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). They need an uninstall first, which
erases their local progress.

## Verifying an APK

```bash
# A release APK: structure + exactly one signer + the RCBFlow certificate
bash tool/ci/verify_apk.sh --mode release path/to/app.apk com.rananjaya.RCBFlow \
  5fb96f9450a5316648cdc4134883e1c2b6d3f008ca32ba2235cff343d3bb44a2

# Any build, signature not checked: package ID, version, no INTERNET
bash tool/ci/verify_apk.sh --mode structure path/to/app.apk com.rananjaya.RCBFlow

shasum -a 256 -c RCBFlow-X.Y.Z-release.apk.sha256   # for a downloaded release
```

The script uses the newest Android build-tools under `$ANDROID_HOME`. In
release mode it:

1. runs `apksigner verify`, which must succeed;
2. reads the signer certificates as PEM (`apksigner verify --print-certs-pem`)
   and computes each SHA-256 with `openssl`.

The check therefore doesn't depend on the wording of `apksigner`'s text output,
which differs between build-tools versions. That difference is what broke the
first release attempt. Text parsing is only a fallback for an `apksigner`
without PEM output. If the check fails, the script prints `apksigner`'s output
(public certificate information only) to make diagnosis easy.

To test the script itself:

```bash
bash tool/ci/tests/verify_apk_test.sh build/app/outputs/flutter-apk/app-release.apk \
  [build/app/outputs/flutter-apk/app-debug.apk]   # optional: checks the INTERNET rejection
```

## Installation and upgrade testing

```bash
adb install -r RCBFlow-X.Y.Z-release.apk   # upgrade in place
adb shell dumpsys package com.rananjaya.RCBFlow | grep -E "versionName|versionCode"
```

1. Install the **previous** release and play a few levels, so there is saved
   progress and an unfinished board.
2. Install the new APK over it with `adb install -r`. Confirm that progress,
   settings and the unfinished board are still there.
3. Launch from the launcher. Check the icon, the name "RCBFlow", and the version
   under Settings on the home screen.
4. Check the log for crashes: `adb logcat | grep -E "FATAL EXCEPTION|E/flutter"`.

`INSTALL_FAILED_UPDATE_INCOMPATIBLE` means the signing key differs. Don't fix
it by uninstalling on players' devices; that erases their data.

## Release checklist

Most checks are automated. Before you merge a pull request, confirm:

- [ ] `version:` in `pubspec.yaml` is bumped by the right amount (MAJOR / MINOR / PATCH) and the build number went up by 1
- [ ] All three CI checks are green
- [ ] Any new permission or network use is documented in [PRIVACY_AND_SECURITY.md](PRIVACY_AND_SECURITY.md)

After the release workflow finishes:

- [ ] The *Releases* page shows "RCBFlow X.Y.Z" with the APK and `.sha256`
- [ ] Upgrade test over the previous release keeps progress (see above)
- [ ] Smoke test: home, a level, levels list, settings, how to play

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
