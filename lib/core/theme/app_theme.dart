import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  /// Light status-bar icons over the dark sky.
  static const systemBars = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.charcoal,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static const _square = RoundedRectangleBorder(
    side: BorderSide(color: AppColors.ink, width: 2),
  );

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.yellow,
      onPrimary: AppColors.ink,
      secondary: AppColors.cyan,
      onSecondary: AppColors.ink,
      error: AppColors.coral,
      surface: AppColors.purple,
      onSurface: AppColors.white,
      onSurfaceVariant: AppColors.gray,
      outline: AppColors.faint,
    );
    final link = TextButton.styleFrom(
      foregroundColor: AppColors.yellow,
      textStyle: AppTextStyles.button,
      shape: const RoundedRectangleBorder(),
      minimumSize: const Size(64, 44),
    );
    const small = AppTextStyles.caption;
    const text = AppTextStyles.button;

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.night,
      fontFamily: AppTextStyles.fontFamily,
      dividerColor: AppColors.ink,
      // Only the system's own pickers and menus still use these.
      textTheme: const TextTheme(
        titleSmall: AppTextStyles.button,
        bodyMedium: AppTextStyles.body,
        bodyLarge: AppTextStyles.body,
        labelLarge: AppTextStyles.button,
      ),
      // Keys move and click; nothing needs to ripple as well.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.yellow,
        selectionColor: Color(0x6654DFF2),
        selectionHandleColor: AppColors.cyan,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _PixelTransitions(),
          TargetPlatform.iOS: _PixelTransitions(),
        },
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.purple,
        headerBackgroundColor: AppColors.charcoal,
        headerForegroundColor: AppColors.yellow,
        headerHeadlineStyle: AppTextStyles.header,
        headerHelpStyle: small,
        weekdayStyle: small,
        dayStyle: text,
        dividerColor: AppColors.ink,
        yearStyle: text,
        shape: _square,
        dayShape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        cancelButtonStyle: link,
        confirmButtonStyle: link,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.purple,
        dialBackgroundColor: AppColors.charcoal,
        dialHandColor: AppColors.yellow,
        dialTextStyle: text,
        hourMinuteTextStyle: const TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 28,
        ),
        hourMinuteColor: AppColors.charcoal,
        hourMinuteTextColor: AppColors.yellow,
        hourMinuteShape: _square,
        dayPeriodTextStyle: text,
        dayPeriodShape: _square,
        dayPeriodColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.yellow
                : AppColors.charcoal),
        dayPeriodTextColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.gray),
        dayPeriodBorderSide: const BorderSide(color: AppColors.ink, width: 2),
        helpTextStyle: small,
        shape: _square,
        cancelButtonStyle: link,
        confirmButtonStyle: link,
      ),
    );
  }
}

/// New screens rise a little and fade in, quickly.
class _PixelTransitions extends PageTransitionsBuilder {
  const _PixelTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final eased =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
            .animate(eased),
        child: child,
      ),
    );
  }
}
