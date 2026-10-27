import 'package:flutter/cupertino.dart';

/// iOS-like palette shared by every screen.
///
/// The app deliberately stays close to Apple's grouped-list language:
/// soft grouped backgrounds, white cards, hairline separators and a single
/// blue accent.
class AppColors {
  const AppColors(this.brightness);

  final Brightness brightness;

  bool get isDark => brightness == Brightness.dark;

  Color get background =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  Color get card =>
      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);

  Color get cardElevated =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF7F7FA);

  Color get separator =>
      isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  Color get label =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  Color get secondaryLabel =>
      isDark ? const Color(0xFF9A9AA0) : const Color(0xFF6C6C70);

  Color get tertiaryLabel =>
      isDark ? const Color(0xFF636366) : const Color(0xFFAEAEB2);

  Color get accent =>
      isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

  Color get green =>
      isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);

  Color get orange =>
      isDark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500);

  Color get red => isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);

  Color get purple =>
      isDark ? const Color(0xFFBF5AF2) : const Color(0xFFAF52DE);

  Color get searchField =>
      isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE9E9EB);

  Color get bar =>
      isDark ? const Color(0xE6000000) : const Color(0xF2F9F9F9);

  Color tint(Color color, [double alpha = 0.12]) =>
      color.withValues(alpha: alpha);
}

extension AppColorsContext on BuildContext {
  AppColors get colors => AppColors(CupertinoTheme.brightnessOf(this));
}

CupertinoThemeData buildCupertinoTheme(Brightness brightness) {
  final colors = AppColors(brightness);

  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: colors.accent,
    primaryContrastingColor: const Color(0xFFFFFFFF),
    scaffoldBackgroundColor: colors.background,
    barBackgroundColor: colors.bar,
    textTheme: CupertinoTextThemeData(
      textStyle: TextStyle(
        color: colors.label,
        fontSize: 17,
        letterSpacing: -0.2,
      ),
      navTitleTextStyle: TextStyle(
        color: colors.label,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      navLargeTitleTextStyle: TextStyle(
        color: colors.label,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      navActionTextStyle: TextStyle(
        color: colors.accent,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
      tabLabelTextStyle: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: colors.label,
      ),
      actionTextStyle: TextStyle(
        color: colors.accent,
        fontSize: 17,
        letterSpacing: -0.2,
      ),
      pickerTextStyle: TextStyle(color: colors.label, fontSize: 21),
      dateTimePickerTextStyle: TextStyle(color: colors.label, fontSize: 21),
    ),
  );
}
