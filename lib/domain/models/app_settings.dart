import 'package:flutter/material.dart';

enum AppThemePreset {
  pastelButter(
    id: 'pastelButter',
    displayName: 'Honey Butter',
    bg: Color(0xFFFFFDE7),
    surface: Color(0xFFFFFFFF),
    primary: Color(0xFF4F46E5),
    headingDark: Color(0xFF0F172A),
    headingWhite: Color(0xFFFFFFFF),
    subtext: Color(0xFF64748B),
    gridLines: Color(0xFFE2E8F0),
    accent: Color(0xFF4338CA),
    border: Color(0xFFCBD5E1),
  ),
  obsidian(
    id: 'obsidian',
    displayName: 'Warm Obsidian',
    bg: Color(0xFF141312),
    surface: Color(0xFF1E1C1A),
    primary: Color(0xFF6366F1),
    headingDark: Color(0xFFF8FAFC),
    headingWhite: Color(0xFFFFFFFF),
    subtext: Color(0xFF94A3B8),
    gridLines: Color(0xFF2C2824),
    accent: Color(0xFF818CF8),
    border: Color(0xFF38332D),
  );

  const AppThemePreset({
    required this.id,
    required this.displayName,
    required this.bg,
    required this.surface,
    required this.primary,
    required this.headingDark,
    required this.headingWhite,
    required this.subtext,
    required this.gridLines,
    required this.accent,
    required this.border,
  });

  final String id;
  final String displayName;
  final Color bg;
  final Color surface;
  final Color primary;
  final Color headingDark;
  final Color headingWhite;
  final Color subtext;
  final Color gridLines;
  final Color accent;
  final Color border;

  static AppThemePreset fromId(String? id) {
    return AppThemePreset.values.firstWhere(
      (e) => e.id == id,
      orElse: () => AppThemePreset.pastelButter,
    );
  }

  bool get isDark => bg.computeLuminance() < 0.5;
}

@immutable
class AppSettings {
  const AppSettings({
    this.isHintEnabled = false,
    this.isSoundEnabled = true,
    this.themeMode = ThemeMode.system,
  });

  final bool isHintEnabled;
  final bool isSoundEnabled;
  final ThemeMode themeMode;

  AppThemePreset get theme {
    switch (themeMode) {
      case ThemeMode.dark:
        return AppThemePreset.obsidian;
      case ThemeMode.light:
        return AppThemePreset.pastelButter;
      case ThemeMode.system:
        final brightness =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        return brightness == Brightness.dark
            ? AppThemePreset.obsidian
            : AppThemePreset.pastelButter;
    }
  }

  AppSettings copyWith({
    bool? isHintEnabled,
    bool? isSoundEnabled,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      isHintEnabled: isHintEnabled ?? this.isHintEnabled,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}
