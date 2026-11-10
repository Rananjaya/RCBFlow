import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow/ui/features/home/views/home_view.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/pump_app.dart';

/// Records every URL the app asks the platform to open, instead of opening a
/// browser. Any attempt to launch something is captured here.
class RecordingUrlLauncher extends UrlLauncherPlatform
    with MockPlatformInterfaceMixin {
  final List<String> launchedUrls = [];
  final List<PreferredLaunchMode> launchModes = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    launchModes.add(options.mode);
    return true;
  }

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    launchedUrls.add(url);
    return true;
  }

  @override
  Future<bool> supportsMode(PreferredLaunchMode mode) async => true;

  @override
  Future<void> closeWebView() async {}
}

Finder get _star => find.byIcon(Icons.star_rounded);
Finder get _heart => find.byIcon(Icons.favorite_rounded);

void main() {
  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform originalLauncher;

  setUp(() {
    mockPlatformVersion();
    originalLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() => UrlLauncherPlatform.instance = originalLauncher);

  Future<void> pumpHome(WidgetTester tester) async {
    setScreenSize(tester, const Size(411, 891));
    await pumpRcbFlowApp(tester);
  }

  group('Star (GitHub) button', () {
    test('points at the RCBFlow repository', () {
      expect(rcbflowRepositoryUrl, 'https://github.com/Rananjaya/RCBFlow');
    });

    testWidgets('opens the RCBFlow repository in an external app', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(_star);
      await tester.pump();

      expect(launcher.launchedUrls, ['https://github.com/Rananjaya/RCBFlow']);
      expect(launcher.launchModes, [PreferredLaunchMode.externalApplication]);
      expect(
        launcher.launchedUrls.any((u) => u.contains('sidhant947')),
        isFalse,
      );
    });

    testWidgets('keeps its original orange star at the top left', (
      tester,
    ) async {
      await pumpHome(tester);

      final icon = tester.widget<Icon>(_star);
      expect(icon.color, const Color(0xFFFF9800));
      expect(icon.size, 20);
      final rect = tester.getRect(_star);
      expect(rect.center.dx, lessThan(411 / 2));
      expect(
        rect.top,
        lessThan(tester.getRect(find.byKey(const Key('home_logo'))).top),
      );
    });
  });

  group('Heart button', () {
    testWidgets('stays visible with its original look at the top right', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(_heart, findsOneWidget);
      expect(find.byKey(const Key('home_heart_button')), findsOneWidget);
      final icon = tester.widget<Icon>(_heart);
      expect(icon.color, const Color(0xFFEF4444));
      expect(icon.size, 20);
      final rect = tester.getRect(_heart);
      expect(rect.center.dx, greaterThan(411 / 2));
      // Same row as the star button.
      expect(rect.center.dy, moreOrLessEquals(tester.getRect(_star).center.dy));
      expect(_heart.hitTestable(), findsOneWidget);
    });

    testWidgets('tapping it launches nothing and stays on home', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(_heart);
      await tester.pumpAndSettle();
      await tester.tap(_heart);
      await tester.pumpAndSettle();

      expect(launcher.launchedUrls, isEmpty);
      expect(find.byType(HomeView), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('home screen offers no link to the original author\'s '
      'Ko-fi page', (tester) async {
    await pumpHome(tester);

    await tester.tap(_star);
    await tester.tap(_heart);
    await tester.pump();

    expect(launcher.launchedUrls.where((u) => u.contains('ko-fi')), isEmpty);
  });
}
