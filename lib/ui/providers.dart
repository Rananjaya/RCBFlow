import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flow/data/repositories/progress_repository.dart';
import 'package:flow/data/services/hive_service.dart';
import 'package:flow/data/services/settings_service.dart';
import 'package:flow/data/services/sound_service.dart';
import 'package:flow/domain/models/app_settings.dart';
import 'package:flow/domain/models/app_version.dart';
import 'package:flow/domain/use_cases/level_generator.dart';
import 'package:flow/ui/features/game/view_models/game_view_model.dart';
import 'package:flow/ui/features/home/view_models/home_view_model.dart';
import 'package:flow/ui/features/settings/view_models/settings_view_model.dart';

final hiveServiceProvider = Provider<HiveService>((ref) {
  throw UnimplementedError();
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  throw UnimplementedError();
});

final soundServiceProvider = Provider<SoundService>((ref) {
  final settingsService = ref.watch(settingsServiceProvider);
  final service = SoundService(settingsService: settingsService);
  ref.onDispose(() => service.dispose());
  return service;
});

final progressRepositoryProvider = ChangeNotifierProvider<ProgressRepository>((
  ref,
) {
  final hiveService = ref.watch(hiveServiceProvider);
  return ProgressRepository(hiveService: hiveService);
});

final levelGeneratorProvider = Provider<LevelGenerator>((ref) {
  return LevelGenerator();
});

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeViewModelState>((ref) {
      final progressRepository = ref.read(progressRepositoryProvider);
      final levelGenerator = ref.read(levelGeneratorProvider);
      return HomeViewModel(
        progressRepository: progressRepository,
        levelGenerator: levelGenerator,
      );
    });

final gameViewModelProvider =
    StateNotifierProvider.autoDispose<GameViewModel, GameViewModelState>((ref) {
      final progressRepository = ref.read(progressRepositoryProvider);
      final levelGenerator = ref.read(levelGeneratorProvider);
      final settingsService = ref.read(settingsServiceProvider);
      final soundService = ref.read(soundServiceProvider);
      return GameViewModel(
        progressRepository: progressRepository,
        levelGenerator: levelGenerator,
        settingsService: settingsService,
        soundService: soundService,
      );
    });

final settingsProvider = StateNotifierProvider<SettingsViewModel, AppSettings>((
  ref,
) {
  final settingsService = ref.watch(settingsServiceProvider);
  return SettingsViewModel(settingsService: settingsService);
});

/// Version of the installed app, read from the platform (Android
/// versionName/versionCode, which Gradle derives from pubspec.yaml).
final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion(version: info.version, buildNumber: info.buildNumber);
});
