import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../widgets/app_palette.dart';

abstract final class AppTheme {
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppPalette.darkSurface : AppPalette.lightSurface;
    final surface2 = isDark ? AppPalette.darkSurface2 : AppPalette.lightSurface2;
    final text = isDark ? AppPalette.darkTextPrimary : AppPalette.lightText;
    final secondary = isDark ? AppPalette.darkText2 : AppPalette.lightText2;
    final tertiary = isDark ? AppPalette.darkText3 : AppPalette.lightText3;
    final accent = isDark ? AppPalette.teal400 : AppPalette.teal500;
    final tint = isDark ? AppPalette.teal900 : AppPalette.teal50;
    final onTint = isDark ? AppPalette.teal200 : AppPalette.teal700;
    final base = ThemeData(useMaterial3: true, brightness: brightness);
    TextStyle type(double size, double line, FontWeight weight,
        {double tracking = 0, Color? color}) => TextStyle(
      fontSize: size, height: line / size, fontWeight: weight,
      letterSpacing: tracking, color: color ?? text,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final textTheme = TextTheme(
      displayLarge: type(34, 38, FontWeight.w700, tracking: -.68),
      displayMedium: type(32, 38, FontWeight.w700, tracking: -.64),
      displaySmall: type(32, 38, FontWeight.w700, tracking: -.64),
      headlineLarge: type(32, 38, FontWeight.w700, tracking: -.64),
      headlineMedium: type(24, 30, const FontWeight(650), tracking: -.36),
      headlineSmall: type(24, 30, const FontWeight(650), tracking: -.36),
      titleLarge: type(19, 25, FontWeight.w600, tracking: -.19),
      titleMedium: type(19, 25, FontWeight.w600, tracking: -.19),
      titleSmall: type(15, 22, FontWeight.w600),
      bodyLarge: type(15, 22, FontWeight.w400),
      bodyMedium: type(15, 22, FontWeight.w400),
      bodySmall: type(13, 18, const FontWeight(450), color: secondary),
      labelLarge: type(15, 22, FontWeight.w600),
      labelMedium: type(13, 18, FontWeight.w600),
      labelSmall: type(12, 16, FontWeight.w600, tracking: .48, color: tertiary),
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppPalette.radiusMd));
    final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.focused)) return accent.withValues(alpha: .24);
      if (states.contains(WidgetState.pressed)) return accent.withValues(alpha: .16);
      if (states.contains(WidgetState.hovered)) return accent.withValues(alpha: .08);
      return null;
    });
    final primary = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
      shape: WidgetStatePropertyAll(shape),
      elevation: const WidgetStatePropertyAll(0),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      animationDuration: AppPalette.motionDuration,
      foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? tertiary : AppPalette.white),
      backgroundColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.disabled) ? surface2 :
        s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered) ? AppPalette.teal600 : AppPalette.teal500),
      overlayColor: overlay,
      side: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.focused)
        ? BorderSide(color: accent.withValues(alpha: .24), width: 3) : BorderSide.none),
    );
    return base.copyWith(
      colorScheme: ColorScheme(
        brightness: brightness, primary: accent, onPrimary: AppPalette.white,
        primaryContainer: tint, onPrimaryContainer: onTint,
        secondary: accent, onSecondary: AppPalette.white,
        secondaryContainer: tint, onSecondaryContainer: onTint,
        error: AppPalette.danger, onError: AppPalette.white,
        errorContainer: AppPalette.danger.withValues(alpha: .12), onErrorContainer: isDark ? AppPalette.danger : AppPalette.dangerText,
        surface: surface, onSurface: text, onSurfaceVariant: secondary,
        surfaceContainerLowest: surface, surfaceContainerLow: surface,
        surfaceContainer: surface2, surfaceContainerHigh: surface2,
        surfaceContainerHighest: surface2, outline: tertiary,
        outlineVariant: text.withValues(alpha: .08), shadow: AppPalette.ink,
        surfaceTint: AppPalette.transparent,
      ),
      scaffoldBackgroundColor: isDark ? AppPalette.darkCanvas : AppPalette.lightCanvas,
      textTheme: base.textTheme.merge(textTheme),
      cardTheme: CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppPalette.radiusLg))),
      filledButtonTheme: FilledButtonThemeData(style: primary),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primary),
      outlinedButtonTheme: OutlinedButtonThemeData(style: primary.copyWith(
        backgroundColor: WidgetStatePropertyAll(tint), foregroundColor: WidgetStatePropertyAll(onTint))),
      textButtonTheme: TextButtonThemeData(style: primary.copyWith(
        backgroundColor: const WidgetStatePropertyAll(AppPalette.transparent),
        foregroundColor: WidgetStatePropertyAll(isDark ? AppPalette.teal300 : AppPalette.teal600))),
      iconButtonTheme: IconButtonThemeData(style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(secondary), overlayColor: overlay,
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)))),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true, floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: textTheme.bodySmall, hintStyle: textTheme.bodyMedium?.copyWith(color: tertiary),
        border: InputBorder.none,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppPalette.radiusMd), borderSide: BorderSide.none),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppPalette.radiusMd), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppPalette.radiusMd), borderSide: const BorderSide(color: AppPalette.teal500, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppPalette.radiusMd), borderSide: const BorderSide(color: AppPalette.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppPalette.radiusMd), borderSide: const BorderSide(color: AppPalette.danger, width: 2)),
        errorStyle: textTheme.bodySmall?.copyWith(color: AppPalette.danger),
      ),
      appBarTheme: AppBarTheme(backgroundColor: surface, foregroundColor: text,
        elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
        titleSpacing: 24, titleTextStyle: textTheme.titleLarge, surfaceTintColor: AppPalette.transparent),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: surface, elevation: 0,
        indicatorColor: tint, height: 72,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? accent : tertiary)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: s.contains(WidgetState.selected) ? accent : secondary))),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: surface,
        elevation: 0, selectedItemColor: accent, unselectedItemColor: tertiary,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), type: BottomNavigationBarType.fixed),
      dividerTheme: DividerThemeData(color: text.withValues(alpha: .08), thickness: 1, space: 24),
      chipTheme: ChipThemeData(backgroundColor: tint, selectedColor: tint,
        labelStyle: textTheme.labelMedium?.copyWith(color: onTint), side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), shape: const StadiumBorder()),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface2, elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppPalette.radiusXl)))),
      dialogTheme: DialogThemeData(backgroundColor: surface2, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppPalette.radiusXl))),
      snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppPalette.radiusMd))),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      pageTransitionsTheme: PageTransitionsTheme(builders: {
        for (final platform in TargetPlatform.values)
          platform: const AppPageTransitionsBuilder(),
      }),
    );
  }
}

class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();
  @override
  Duration get transitionDuration => AppPalette.motionDuration;
  @override
  Duration get reverseTransitionDuration => AppPalette.motionDuration;
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = animation.drive(CurveTween(curve: AppPalette.motionCurve));
    return FadeTransition(opacity: curved, child: SlideTransition(
      position: curved.drive(Tween(begin: const Offset(.045, 0), end: Offset.zero)), child: child));
  }
}
