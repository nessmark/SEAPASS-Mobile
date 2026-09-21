import 'package:flutter/material.dart';

/// SeaPass Design System v1. All visual colour, geometry and motion tokens.
///
/// NEUTRAL IS NOT FLAT: canvas -> surface is 1.138:1 (measured), and cards carry
/// a hairline. A <1.10:1 step with no edge makes the card vanish into the page.
/// In light mode the CANVAS is the grey and cards are white, never both near-white.
///
/// COLOUR RULE: the teal ramp is an ACCENT only — buttons, active/selected states,
/// links, focus rings, chips and marks. Canvases, surfaces, text, hairlines and
/// shadows are pure greys (R=G=B) in both themes. Dark and white only.
abstract final class AppPalette {
  static const teal50 = Color(0xFFF0F9FA);
  static const teal100 = Color(0xFFDCF0F2);
  static const teal200 = Color(0xFFB8E1E6);
  static const teal300 = Color(0xFF7BBEC7);
  static const teal400 = Color(0xFF3FA0AD);
  static const teal500 = Color(0xFF1D8895);
  static const teal600 = Color(0xFF166D78);
  static const teal700 = Color(0xFF12555E);
  static const teal800 = Color(0xFF0E4149);
  static const teal900 = Color(0xFF0A3037);

  static const lightCanvas = Color(0xFFF2F2F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF7F7F7);
  static const lightText = Color(0xFF171717);
  static const lightText2 = Color(0xFF666666);
  static const lightText3 = Color(0xFF949494);
  static const lightHairline = Color(0x1A000000);
  static const darkCanvas = Color(0xFF0A0A0A);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkSurface2 = Color(0xFF242424);
  static const darkTextPrimary = Color(0xFFF5F5F5);
  static const darkText2 = Color(0xFFA3A3A3);
  static const darkText3 = Color(0xFF737373);
  static const darkHairline = Color(0x16FFFFFF);
  static const darkTopEdge = Color(0x0FFFFFFF);
  static const transparent = Color(0x00000000);
  static const ink = Color(0xFF000000);
  static const white = lightSurface;

  static const success = Color(0xFF1FA971);
  static const warning = Color(0xFFE9A23B);
  static const danger = Color(0xFFE5484D);
  static const info = teal500;
  static const successTint = Color(0xFFE8F6F0);
  static const warningTint = Color(0xFFFDF4E8);
  static const dangerTint = Color(0xFFFBE9EA);
  static const infoTint = teal50;
  // 700-level semantic text for readable 12% tinted pills.
  static const successText = Color(0xFF126442);
  static const warningText = Color(0xFF885A16);
  static const dangerText = Color(0xFFAA272B);

  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 20.0;
  static const radiusXl = 28.0;
  static const radiusPill = 999.0;
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space40 = 40.0;
  static const space56 = 56.0;
  static const space72 = 72.0;

  static const elevation1 = [
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 6), blurRadius: 16),
  ];
  static const elevation2 = [
    BoxShadow(color: Color(0x0D000000), offset: Offset(0, 2), blurRadius: 4),
    BoxShadow(color: Color(0x14000000), offset: Offset(0, 12), blurRadius: 28),
  ];
  static const elevation3 = [
    BoxShadow(color: Color(0x2E000000), offset: Offset(0, 24), blurRadius: 64),
  ];
  static List<BoxShadow> shadows(Brightness brightness, {int level = 1}) {
    final source = switch (level) { 3 => elevation3, 2 => elevation2, _ => elevation1 };
    return brightness == Brightness.light ? source : [
      for (final shadow in source)
        shadow.copyWith(color: shadow.color.withValues(alpha: shadow.color.a * .5)),
    ];
  }

  static const motionCurve = Cubic(.32, .72, 0, 1);
  static const motionDuration = Duration(milliseconds: 240);
  static const motionFast = Duration(milliseconds: 200);
  static const motionSlow = Duration(milliseconds: 260);
  static const shimmerDuration = Duration(milliseconds: 1400);
  static Duration duration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : motionDuration;

  @Deprecated('Use teal500 or the theme primary colour.')
  static const mintGreen = teal500;
  @Deprecated('Use lightCanvas or the theme scaffold background.')
  static const lightBackground = lightCanvas;
  @Deprecated('Use lightText or the theme onSurface colour.')
  static const darkText = lightText;
  @Deprecated('Use lightSurface or the theme surface colour.')
  static const cardBackground = lightSurface;
  @Deprecated('Use lightText3 or AppColors.of(context).text3.')
  static const subtleGrey = lightText3;
}

/// Context-bound neutral roles; keeps screens responsive to system brightness.
class AppColors {
  AppColors.of(BuildContext context) : dark = Theme.of(context).brightness == Brightness.dark;
  final bool dark;
  Color get canvas => dark ? AppPalette.darkCanvas : AppPalette.lightCanvas;
  Color get surface => dark ? AppPalette.darkSurface : AppPalette.lightSurface;
  Color get surface2 => dark ? AppPalette.darkSurface2 : AppPalette.lightSurface2;
  Color get text => dark ? AppPalette.darkTextPrimary : AppPalette.lightText;
  Color get text2 => dark ? AppPalette.darkText2 : AppPalette.lightText2;
  Color get text3 => dark ? AppPalette.darkText3 : AppPalette.lightText3;
  Color get hairline => dark ? AppPalette.darkHairline : AppPalette.lightHairline;
  Color get accent => dark ? AppPalette.teal400 : AppPalette.teal500;
  Color get tint => dark ? AppPalette.teal900 : AppPalette.teal50;
  Color get onTint => dark ? AppPalette.teal200 : AppPalette.teal700;
}
