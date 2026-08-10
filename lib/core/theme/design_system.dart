import 'package:flutter/material.dart';

class AppColors {
  /// Kun/tun rejimi. ThemeController buni o'zgartiradi, so'ng ilova qayta chiziladi.
  /// Shu tufayli `AppColors.*` ishlatilgan barcha joy avtomatik tema-mos bo'ladi.
  static bool isDarkMode = false;

  // Rang o'zgarmaydiganlar (ikkala rejimda ham bir xil).
  static const Color primary = Color(0xFF2F6BFF);
  static const Color danger = Color(0xFFE23744);

  // Tema-mos ranglar (kun/tun).
  static Color get bg => isDarkMode ? const Color(0xFF0F141A) : const Color(0xFFF5F6F8);
  static Color get surface => isDarkMode ? const Color(0xFF1B222B) : Colors.white;
  static Color get surfaceAlt => isDarkMode ? const Color(0xFF232B35) : const Color(0xFFEDEFF2);
  static Color get textPrimary => isDarkMode ? const Color(0xFFECEFF3) : const Color(0xFF111111);
  static Color get textSecondary => isDarkMode ? const Color(0xFF9AA4B0) : const Color(0xFF70757D);
  static Color get border => isDarkMode ? const Color(0xFF2C3540) : const Color(0xFFE3E7ED);
}

class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
}

class AppRadius {
  static const double card = 16;
  static const double button = 12;
  static const double input = 12;
}

class AppShadows {
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
}

class AppTextStyles {
  static TextStyle get title => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );
  static TextStyle get subtitle => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );
  static TextStyle get caption => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );
}
