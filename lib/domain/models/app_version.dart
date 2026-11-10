import 'package:flutter/foundation.dart';

/// The installed application's version as reported by the platform.
///
/// On Android these values come from the APK's `versionName` / `versionCode`,
/// which the Flutter Gradle plugin takes from `version:` in pubspec.yaml
/// (e.g. `1.0.0+1` -> versionName `1.0.0`, versionCode `1`).
@immutable
class AppVersion {
  const AppVersion({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;

  /// Human-readable label, e.g. `Version 1.0.0 (1)`.
  ///
  /// The build number is omitted when the platform does not report one.
  String get label {
    final build = buildNumber.trim();
    return build.isEmpty ? 'Version $version' : 'Version $version ($build)';
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.version == version &&
      other.buildNumber == buildNumber;

  @override
  int get hashCode => Object.hash(version, buildNumber);

  @override
  String toString() => 'AppVersion($version+$buildNumber)';
}
