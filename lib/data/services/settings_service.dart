import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flow/domain/models/app_settings.dart';

class SettingsService {
  static const String _boxName = 'flow_settings';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  AppSettings getSettings() {
    final box = Hive.box(_boxName);
    final isHintEnabled = box.get('hint_enabled', defaultValue: false) as bool;
    final isSoundEnabled = box.get('sound_enabled', defaultValue: true) as bool;
    // Added in 1.1.0. Installs from before then have no key, so vibration
    // stays on (their existing behaviour).
    final isVibrationEnabled =
        box.get('vibration_enabled', defaultValue: true) as bool;
    final themeModeStr = box.get('theme_mode') as String?;
    final ThemeMode themeMode;
    if (themeModeStr != null) {
      themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeModeStr,
        orElse: () => ThemeMode.system,
      );
    } else {
      final legacyTheme = box.get('app_theme') as String?;
      if (legacyTheme == 'obsidian') {
        themeMode = ThemeMode.dark;
      } else if (legacyTheme == 'pastelButter') {
        themeMode = ThemeMode.light;
      } else {
        themeMode = ThemeMode.system;
      }
    }
    return AppSettings(
      isHintEnabled: isHintEnabled,
      isSoundEnabled: isSoundEnabled,
      isVibrationEnabled: isVibrationEnabled,
      themeMode: themeMode,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final box = Hive.box(_boxName);
    await box.put('hint_enabled', settings.isHintEnabled);
    await box.put('sound_enabled', settings.isSoundEnabled);
    await box.put('vibration_enabled', settings.isVibrationEnabled);
    await box.put('theme_mode', settings.themeMode.name);
  }
}
