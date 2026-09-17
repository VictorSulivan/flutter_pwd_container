import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF070B14);
  static const card = Color(0xFF0C1322);
  static const cardBorder = Color(0xFF1B2740);
  static const cyan = Color(0xFF3DDCFF);
  static const cyanSoft = Color(0xFF5CE1FF);
  static const muted = Color(0xFF8B9BB4);
  static const iconWell = Color(0xFF151E30);
}

ThemeData buildAppTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      surface: AppColors.card,
      onPrimary: Color(0xFF041018),
    ),
  );
}
