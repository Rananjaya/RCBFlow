# Privacy and Security

RCBFlow is meant to stay a simple, private, offline puzzle game. This document
records what the app does with data today and sets the rules every future change
and pull request has to follow.

It describes the state of the code reviewed on **2026-11-10** (version 1.0.0+1).
It is an engineering record, not a legal privacy policy, and it doesn't promise
the app is perfectly private or secure. Each finding is marked **Verified**
(checked against the source code or built APK) or **Assumption** (believed true
but not independently confirmed).

## Principles

- No advertising.
- No analytics or telemetry.
- No user tracking or identifiers.
- No network access unless a feature truly needs it and has been approved.
- No permissions beyond what a feature strictly needs.
- No background services.
- Game data stays on the device.

## Data handling

| Data | Where it is stored | Leaves the device? |
|---|---|---|
| Current level, highest level completed, total moves | Hive box `flow_user_progress` in the app's private documents directory | No, apart from OS backup (below) |
| Best moves and best time per level | Same box | No, apart from OS backup |
| Unfinished board (paths, moves, elapsed time) | Same box | No, apart from OS backup |
| Settings: hints, sound, theme mode | Hive box `flow_settings` | No, apart from OS backup |

- **Verified:** the app doesn't collect names, accounts, contacts, location,
  device identifiers or any free text. Nothing is stored outside the two boxes
  above.
- **Verified:** progress is written by `ProgressRepository` → `HiveService`, and
  settings by `SettingsService`. **Reset Progress** in Settings clears the
  progress record.
- **Verified:** `AndroidManifest.xml` doesn't set `android:allowBackup`, so
  Android's default of `true` applies.
- **Assumption, based on Android's documented behaviour:** if the user has
  turned on device backup, Android Auto Backup may include these files in the
  user's own backup or in a device-to-device transfer. RCBFlow doesn't send them
  anywhere itself.

### Android backup: implications

These come from Android's documentation and weren't tested on a device:

- **Where the data goes:**
  - Auto Backup uploads app files to the **user's own** Google account storage,
    only if the user has turned on device backup.
  - On recent Android versions the backup is end-to-end encrypted when the device
    has a screen lock.
  - Device-to-device transfer copies the files when the user sets up a new phone.
- **What would be included:** only game progress and the three settings. No
  personal information. The developer never receives it.
- **Benefit:** progress survives a phone change or reinstall.
- **Cost:** a copy of the game data exists outside the device, under the user's
  Google account.

**Recommendation (not applied):** keep backup enabled. The data isn't sensitive,
the user controls backup at the system level, and it never reaches the
developer.

If you'd rather keep everything strictly on the device, set
`android:allowBackup="false"` in `android/app/src/main/AndroidManifest.xml`.
Android 12 and later may also need `android:dataExtractionRules` to exclude
device-to-device transfer. This is the maintainer's decision.

## Network behaviour

### Requests the app makes

- **Verified:** there is no networking code in `lib/`: no HTTP client, sockets
  or remote config.
- **Verified:** the release APK doesn't request `android.permission.INTERNET`, so
  Android blocks the app's own process from opening network connections.
- **Verified:** sound effects are played with `AssetSource` from bundled files.
  `audioplayers` can stream URLs, but that feature isn't used.

### Links opened after a tap

- **Verified:** the only external link is the **star** button on the home
  screen. It opens `https://github.com/Rananjaya/RCBFlow` through `url_launcher`
  in an external app (the browser).
- **Verified:** the heart button on the home screen does nothing.
- **Verified:** the upstream Ko-fi and Liberapay donation links were removed from
  the app (home heart, level-complete screen and Settings).
- Anything that happens in the browser after that link opens is outside the app
  and covered by the browser's and GitHub's own policies.

### Dependencies with network-related features

| Package | Network capability | Used by RCBFlow? |
|---|---|---|
| `url_launcher` | Hands URLs to other apps; bundles an in-app WebView activity (`io.flutter.plugins.urllauncher.WebViewActivity`) | Only for the star button, with `LaunchMode.externalApplication`. The WebView activity is declared but not used. |
| `audioplayers` | Can play remote URLs | No, local assets only |
| `package_info_plus` | Its **web** implementation fetches `version.json` | No, Android reads the version from the package manager |

### Debug builds

**Verified:** the debug and profile manifests
(`android/app/src/debug|profile/AndroidManifest.xml`) add `INTERNET` so Flutter's
development tools (hot reload, debugger) can connect. This permission is not in
release builds.

## Android permissions (release APK)

**Verified** with `aapt2 dump badging` and the merged manifest of
`app-release.apk` (version 1.0.0, versionCode 1):

| Permission or declaration | Source | Purpose |
|---|---|---|
| `com.rananjaya.RCBFlow.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (signature level) | AndroidX Core | Keeps the app's runtime broadcast receivers private to the app. Not a user-facing permission. |
| `<queries>` for `android.intent.action.PROCESS_TEXT` (`text/plain`) | Flutter engine template | Lets text-selection menus list "process text" actions. Grants no data access. |

**Other components in the APK (verified):**

- `androidx.startup.InitializationProvider` (lifecycle and profile installer
  start-up);
- `androidx.profileinstaller.ProfileInstallReceiver` (installs ahead-of-time
  compilation profiles);
- the unused `url_launcher` WebView activity.

None of these is a background service that runs on its own.

## Third-party components

**Direct runtime dependencies (verified):**

- `flutter_riverpod`;
- `hive` and `hive_flutter`;
- `url_launcher`;
- `audioplayers`;
- `package_info_plus`;
- `cupertino_icons`.

`flutter_launcher_icons` is a development tool and isn't in the APK.

**Verified:** none of them is an analytics, advertising, crash-reporting or
tracking SDK. Licence details are in
[RELEASE.md](RELEASE.md#licensing-and-third-party-components).

## Rules for future changes

Every new feature and pull request must follow these rules:

1. **No analytics or telemetry** without the maintainer's explicit, written
   approval, and then only if users opt in.
2. **No advertisements**, ad SDKs or ad-supported builds.
3. **No user tracking:** no device IDs, advertising IDs, fingerprinting or
   cross-app tracking.
4. **No `INTERNET` permission in release builds** unless a feature genuinely
   needs it and the need is documented here first.
5. **Keep personal game data local.** Any sync or export feature must be opt-in
   and documented.
6. **No unnecessary third-party services** (crash reporters, cloud backends,
   remote config, login).
7. **Review every new dependency** before adding it:
   - check its licence;
   - check its permissions and manifest entries;
   - check its network use and transitive dependencies;
   - prefer well-maintained packages, or none at all.
8. **Review permissions** on every release. Compare the release APK with the
   previous one:

   ```bash
   $ANDROID_HOME/build-tools/<version>/aapt2 dump badging \
     build/app/outputs/flutter-apk/app-release.apk | grep uses-permission
   ```

9. **Review network activity:** search for networking code (`http`, `Socket`,
   `HttpClient`, `UrlSource`, `launchUrl`), and make sure any link opens only
   after a user taps something.
10. **Test privacy-sensitive behaviour.** For example,
    `test/ui/home/home_links_test.dart` checks which URLs the home screen can open
    and that the heart button opens nothing.

### Pull request checklist

- [ ] No new permission in the release APK, or the new permission is documented and justified here
- [ ] No new network calls, or each is documented and justified here
- [ ] New dependencies reviewed (licence, permissions, network, maintenance)
- [ ] Data stored by the feature listed under **Data handling**
- [ ] Tests cover the privacy-relevant behaviour

## Known gaps

- Android Auto Backup is left at its default. The implications and the
  recommendation are under *Android backup: implications* above. It is the
  maintainer's decision.
- Releases are signed with a permanent release key. The CI receives it only
  through encrypted repository secrets, and the release workflow checks the
  certificate fingerprint. See
  [RELEASE.md](RELEASE.md#the-permanent-signing-keystore).
- The `url_launcher` in-app WebView activity ships in the APK even though it is
  unused. It is harmless without `INTERNET`, but worth knowing about.
