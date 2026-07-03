import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFFC4612F);
  static const Color primaryLight = Color(0xFFF2E3D6);
  static const Color primaryDark = Color(0xFFA94E22);
  static const Color success = Color(0xFF52C41A);
  static const Color warning = Color(0xFFFAAD14);
  static const Color error = Color(0xFFF5222D);
  static const Color textPrimary = Color(0xFF1F2421);
  static const Color textSecondary = Color(0xFF5C635D);
  static const Color textPlaceholder = Color(0xFF999999);
  static const Color bgPrimary = Color(0xFFF7F4EF);
  static const Color bgSecondary = Color(0xFFFBF9F5);
  static const Color bgTertiary = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE7E1D7);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double round = 20;
  static const double full = 999;
}

class AppFontSize {
  static const double xs = 10;
  static const double sm = 12;
  static const double base = 14;
  static const double lg = 16;
  static const double xl = 18;
  static const double xxl = 22;
  static const double title = 28;
}

class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

enum ScreenType { mobile, tablet, desktop }

ScreenType getScreenType(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= AppBreakpoints.desktop) return ScreenType.desktop;
  if (width >= AppBreakpoints.tablet) return ScreenType.tablet;
  return ScreenType.mobile;
}

bool isDesktopLayout(BuildContext context) =>
    getScreenType(context) == ScreenType.desktop;
bool isMobileLayout(BuildContext context) =>
    getScreenType(context) == ScreenType.mobile;
