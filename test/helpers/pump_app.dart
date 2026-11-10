import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flow/main.dart';
import 'package:flow/ui/providers.dart';

import 'test_doubles.dart';

/// Holds the doubles used by a pumped app so tests can inspect them.
class TestApp {
  TestApp({
    InMemoryHiveService? hive,
    InMemorySettingsService? settings,
    FakeLevelGenerator? levelGenerator,
    FakeSoundService? sound,
  }) : hive = hive ?? InMemoryHiveService(),
       settings = settings ?? InMemorySettingsService(),
       levelGenerator = levelGenerator ?? FakeLevelGenerator(),
       sound = sound ?? FakeSoundService();

  final InMemoryHiveService hive;
  final InMemorySettingsService settings;
  final FakeLevelGenerator levelGenerator;
  final FakeSoundService sound;
}

/// Mocks the platform version info the way Android reports it for
/// `version: <version>+<buildNumber>` in pubspec.yaml.
void mockPlatformVersion({String version = '1.0.0', String buildNumber = '1'}) {
  PackageInfo.setMockInitialValues(
    appName: 'RCBFlow',
    packageName: 'com.rananjaya.RCBFlow',
    version: version,
    buildNumber: buildNumber,
    buildSignature: '',
  );
}

/// Sets the logical screen size for the current test and restores it after.
void setScreenSize(WidgetTester tester, Size logicalSize, {double dpr = 1}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = logicalSize * dpr;
  addTearDown(tester.view.reset);
}

/// Pumps the real app root ([FlowApp]) with in-memory services.
Future<TestApp> pumpRcbFlowApp(WidgetTester tester, {TestApp? app}) async {
  final testApp = app ?? TestApp();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hiveServiceProvider.overrideWithValue(testApp.hive),
        settingsServiceProvider.overrideWithValue(testApp.settings),
        soundServiceProvider.overrideWithValue(testApp.sound),
        levelGeneratorProvider.overrideWithValue(testApp.levelGenerator),
      ],
      child: const FlowApp(),
    ),
  );
  // Let initState microtasks (progress + version loading) complete.
  await tester.pump();
  await tester.pump();
  return testApp;
}

/// Unmounts the app so auto-disposed view models cancel their timers.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
