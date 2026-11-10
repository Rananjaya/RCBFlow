import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow/domain/models/app_version.dart';
import 'package:flow/ui/providers.dart';

import '../helpers/pump_app.dart';

/// Reads `version: X.Y.Z+N` from pubspec.yaml - the single source of truth the
/// Flutter Gradle plugin turns into Android versionName / versionCode.
({String name, String build}) readPubspecVersion() {
  final line = File('pubspec.yaml')
      .readAsLinesSync()
      .firstWhere((l) => l.startsWith('version:'));
  final value = line.substring('version:'.length).trim();
  final parts = value.split('+');
  return (name: parts[0], build: parts.length > 1 ? parts[1] : '');
}

void main() {
  group('AppVersion formatting', () {
    test('formats version and build number as "Version X (N)"', () {
      expect(
        const AppVersion(version: '1.0.0', buildNumber: '1').label,
        'Version 1.0.0 (1)',
      );
      expect(
        const AppVersion(version: '2.10.3', buildNumber: '42').label,
        'Version 2.10.3 (42)',
      );
    });

    test('omits the build number when the platform reports none', () {
      expect(
        const AppVersion(version: '1.0.0', buildNumber: '').label,
        'Version 1.0.0',
      );
      expect(
        const AppVersion(version: '1.0.0', buildNumber: '  ').label,
        'Version 1.0.0',
      );
    });

    test('value equality', () {
      expect(
        const AppVersion(version: '1.0.0', buildNumber: '1'),
        const AppVersion(version: '1.0.0', buildNumber: '1'),
      );
      expect(
        const AppVersion(version: '1.0.0', buildNumber: '1'),
        isNot(const AppVersion(version: '1.0.0', buildNumber: '2')),
      );
    });
  });

  group('Version source', () {
    test('pubspec.yaml declares a version with a build number', () {
      final v = readPubspecVersion();
      expect(v.name, matches(RegExp(r'^\d+\.\d+\.\d+$')));
      expect(v.build, matches(RegExp(r'^\d+$')));
    });

    test('appVersionProvider reads the platform package info', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      mockPlatformVersion(version: '3.4.5', buildNumber: '67');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final version = await container.read(appVersionProvider.future);

      expect(version, const AppVersion(version: '3.4.5', buildNumber: '67'));
    });

    testWidgets('home shows whatever version the platform reports '
        '(not a hardcoded value)', (tester) async {
      setScreenSize(tester, const Size(411, 891));
      mockPlatformVersion(version: '9.8.7', buildNumber: '654');
      await pumpRcbFlowApp(tester);

      expect(find.text('Version 9.8.7 (654)'), findsOneWidget);
      expect(find.text('Version 1.0.0 (1)'), findsNothing);
    });

    testWidgets('home shows the pubspec version as Android reports it', (
      tester,
    ) async {
      // On Android, PackageInfo returns versionName/versionCode, which the
      // Flutter Gradle plugin sets from pubspec.yaml's `version:` field.
      final v = readPubspecVersion();
      setScreenSize(tester, const Size(411, 891));
      mockPlatformVersion(version: v.name, buildNumber: v.build);
      await pumpRcbFlowApp(tester);

      expect(find.text('Version ${v.name} (${v.build})'), findsOneWidget);
    });
  });
}
