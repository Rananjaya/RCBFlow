import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flow/data/services/app_haptics.dart';
import 'package:flow/data/services/settings_service.dart';
import 'package:flow/domain/models/app_settings.dart';
import 'package:flow/ui/core/theme/app_colors.dart';

class SettingsViewModel extends StateNotifier<AppSettings> {
  SettingsViewModel({required this.settingsService})
      : super(settingsService.getSettings()) {
    AppColors.currentTheme = state.theme;
    AppHaptics.enabled = state.isVibrationEnabled;
  }

  final SettingsService settingsService;

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    AppColors.currentTheme = state.theme;
    await settingsService.saveSettings(state);
  }

  Future<void> setTheme(AppThemePreset theme) async {
    final mode =
        theme == AppThemePreset.obsidian ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(mode);
  }

  Future<void> toggleHintEnabled(bool value) async {
    state = state.copyWith(isHintEnabled: value);
    await settingsService.saveSettings(state);
  }

  Future<void> toggleSoundEnabled(bool value) async {
    state = state.copyWith(isSoundEnabled: value);
    await settingsService.saveSettings(state);
  }

  /// Applies immediately: [AppHaptics] is updated before the setting is saved.
  Future<void> toggleVibrationEnabled(bool value) async {
    state = state.copyWith(isVibrationEnabled: value);
    AppHaptics.enabled = value;
    await settingsService.saveSettings(state);
  }
}
