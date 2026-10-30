import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flow/data/services/hive_service.dart';
import 'package:flow/data/services/settings_service.dart';
import 'package:flow/domain/models/app_settings.dart';
import 'package:flow/ui/core/theme/app_colors.dart';
import 'package:flow/ui/core/theme/app_theme.dart';
import 'package:flow/ui/providers.dart';
import 'package:flow/ui/features/home/views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final hiveService = HiveService();
  await hiveService.init();

  final settingsService = SettingsService();
  await settingsService.init();

  final initialSettings = settingsService.getSettings();
  AppColors.currentTheme = initialSettings.theme;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  runApp(
    ProviderScope(
      overrides: [
        hiveServiceProvider.overrideWithValue(hiveService),
        settingsServiceProvider.overrideWithValue(settingsService),
      ],
      child: const FlowApp(),
    ),
  );
}

class FlowApp extends ConsumerWidget {
  const FlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    AppColors.currentTheme = settings.theme;
    return MaterialApp(
      title: 'Flow',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        AppColors.currentTheme =
            isDark ? AppThemePreset.obsidian : AppThemePreset.pastelButter;
        return child!;
      },
      home: const HomeView(),
      debugShowCheckedModeBanner: false,
    );
  }
}
