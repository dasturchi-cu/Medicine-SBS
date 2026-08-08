import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2F6BFF);
  static const Color bg = Color(0xFFF5F6F8);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFEDEFF2);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF70757D);
  static const Color border = Color(0xFFE3E7ED);
  static const Color danger = Color(0xFFE23744);
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
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );
}
