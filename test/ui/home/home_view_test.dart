import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow/domain/models/user_progress.dart';
import 'package:flow/ui/features/home/views/home_view.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_doubles.dart';

const _gameButtons = ['Play', 'Levels', 'Random', 'How to Play', 'Settings'];

Finder get _logo => find.byKey(const Key('home_logo'));
Finder get _title => find.byKey(const Key('home_title'));
Finder get _version => find.byKey(const Key('home_version'));

void main() {
  setUp(() => mockPlatformVersion(version: '1.0.0', buildNumber: '1'));

  group('Home screen content', () {
    testWidgets('renders the logo, RCBFlow title, all buttons and version', (
      tester,
    ) async {
      setScreenSize(tester, const Size(411, 891));
      await pumpRcbFlowApp(tester);

      expect(find.byType(HomeView), findsOneWidget);
      expect(_logo, findsOneWidget);
      expect(_title, findsOneWidget);
      expect(tester.widget<Text>(_title).data, 'RCBFlow');
      expect(find.text('Flow'), findsNothing);
      for (final label in _gameButtons) {
        expect(find.text(label), findsOneWidget, reason: '$label button');
      }
      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('logo uses the official RCBFlow asset without distortion', (
      tester,
    ) async {
      setScreenSize(tester, const Size(411, 891));
      await pumpRcbFlowApp(tester);

      final image = tester.widget<Image>(_logo);
      expect(image.image, isA<ResizeImage>());
      final provider = (image.image as ResizeImage).imageProvider;
      expect(provider, isA<AssetImage>());
      expect((provider as AssetImage).assetName, homeLogoAsset);
      expect(homeLogoAsset, 'assets/branding/rcbflow_logo_transparent.png');
      // Square artwork rendered in a square box with BoxFit.contain keeps
      // the original aspect ratio.
      expect(image.fit, BoxFit.contain);
      final size = tester.getSize(_logo);
      expect(size.width, size.height);
      expect(image.semanticLabel, 'RCBFlow logo');
    });

    testWidgets('logo is horizontally centred and directly above the title', (
      tester,
    ) async {
      setScreenSize(tester, const Size(411, 891));
      await pumpRcbFlowApp(tester);

      final screenCentreX =
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;
      final logoRect = tester.getRect(_logo);
      final titleRect = tester.getRect(_title);

      expect(logoRect.center.dx, moreOrLessEquals(screenCentreX));
      expect(titleRect.center.dx, moreOrLessEquals(screenCentreX));
      expect(logoRect.bottom, lessThanOrEqualTo(titleRect.top));
      // "Directly below": only the small fixed gap separates them.
      expect(titleRect.top - logoRect.bottom, lessThan(24));
      // Logo sits below the top bar and above the Play button.
      expect(logoRect.bottom, lessThan(tester.getRect(find.text('Play')).top));
    });

    testWidgets('buttons keep their original order below the title', (
      tester,
    ) async {
      setScreenSize(tester, const Size(411, 891));
      await pumpRcbFlowApp(tester);

      var previousTop = tester.getRect(_title).bottom;
      for (final label in _gameButtons) {
        final top = tester.getRect(find.text(label)).top;
        expect(top, greaterThan(previousTop), reason: '$label order');
        previousTop = top;
      }
    });

    testWidgets('version label is centred directly below Settings', (
      tester,
    ) async {
      setScreenSize(tester, const Size(411, 891));
      await pumpRcbFlowApp(tester);

      final settingsButton = find.ancestor(
        of: find.text('Settings'),
        matching: find.byType(AnimatedContainer),
      );
      final settingsRect = tester.getRect(settingsButton);
      final versionRect = tester.getRect(_version);

      expect(versionRect.top, greaterThanOrEqualTo(settingsRect.bottom));
      expect(versionRect.top - settingsRect.bottom, lessThan(32));
      expect(versionRect.center.dx, moreOrLessEquals(settingsRect.center.dx));
      expect(tester.widget<Text>(_version).textAlign, TextAlign.center);
      // Small, subtle typography compared to the buttons.
      expect(tester.widget<Text>(_version).style!.fontSize, lessThan(15));
    });

    testWidgets('shows the saved current level in the header badge', (
      tester,
    ) async {
      setScreenSize(tester, const Size(411, 891));
      await pumpRcbFlowApp(
        tester,
        app: TestApp(
          hive: InMemoryHiveService(
            const UserProgress(currentLevel: 7, highestLevelCompleted: 6),
          ),
        ),
      );

      expect(find.text('Level 7'), findsOneWidget);
    });
  });

  group('Responsive layout', () {
    // Usable heights after status/navigation bars on common phones/tablets.
    const fitsWithoutScrolling = <String, Size>{
      'small phone (360x568 usable)': Size(360, 568),
      'compact phone (360x640)': Size(360, 640),
      'large phone (411x891)': Size(411, 891),
      'tablet (800x1232)': Size(800, 1232),
    };

    for (final entry in fitsWithoutScrolling.entries) {
      testWidgets('${entry.key}: no overflow and no scrolling needed', (
        tester,
      ) async {
        setScreenSize(tester, entry.value);
        await pumpRcbFlowApp(tester);

        expect(tester.takeException(), isNull);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.maxScrollExtent, 0);
        // Everything is on screen at once.
        for (final finder in [_logo, _title, _version, find.text('Settings')]) {
          final rect = tester.getRect(finder);
          expect(rect.bottom, lessThanOrEqualTo(entry.value.height));
          expect(rect.top, greaterThanOrEqualTo(0));
        }
        final logoSize = tester.getSize(_logo).width;
        expect(logoSize, inInclusiveRange(56, 168));
      });
    }

    const veryShort = <String, Size>{
      'tiny phone (320x480)': Size(320, 480),
      'landscape phone (640x360)': Size(640, 360),
    };

    for (final entry in veryShort.entries) {
      testWidgets(
        '${entry.key}: no overflow, scrolls to Settings and version',
        (tester) async {
          setScreenSize(tester, entry.value);
          await pumpRcbFlowApp(tester);

          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(_version, 100);
          expect(tester.takeException(), isNull);
          expect(
            tester.getRect(_version).bottom,
            lessThanOrEqualTo(entry.value.height),
          );
          expect(find.text('Settings').hitTestable(), findsOneWidget);
        },
      );
    }

    testWidgets('large text scale does not overflow', (tester) async {
      setScreenSize(tester, const Size(360, 640));
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpRcbFlowApp(tester);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(_version, 100);
      expect(tester.takeException(), isNull);
    });
  });
}
