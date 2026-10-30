import 'package:flutter/material.dart';
import 'package:flow/domain/models/app_settings.dart';

class AppColors {
  AppColors._();

  static AppThemePreset currentTheme = AppThemePreset.pastelButter;

  static Color get primary => currentTheme.primary;
  static Color get accent => currentTheme.accent;
  static Color get headingDark => currentTheme.headingDark;
  static Color get headingWhite => currentTheme.headingWhite;
  static Color get subtext => currentTheme.subtext;
  static Color get bg => currentTheme.bg;
  static Color get gridLines => currentTheme.gridLines;
  static Color get surface => currentTheme.surface;
  static Color get border => currentTheme.border;
}

class GameColors {
  GameColors._();

  static const Color successGreen = Color(0xFF10B981);
}

class FlowColors {
  FlowColors._();

  static const List<Color> palette = [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFFF97316),
    Color(0xFF06B6D4),
    Color(0xFFA855F7),
    Color(0xFFEC4899),
    Color(0xFF84CC16),
    Color(0xFFF8FAFC),
    Color(0xFFD97706),
    Color(0xFF14B8A6),
  ];

  static Color getColor(int colorId) {
    if (colorId <= 0) return Colors.transparent;
    return palette[(colorId - 1) % palette.length];
  }
}
