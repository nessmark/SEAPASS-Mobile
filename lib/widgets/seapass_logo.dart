import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_palette.dart';

/// The canonical SeaPass logo widget used across the entire app.
///
/// Renders the official mobile SVG asset
/// with fallback to the MaterialCommunityIcons ferry icon.
class SeaPassLogo extends StatelessWidget {
  const SeaPassLogo({
    super.key,
    this.size = 72,
    this.color = AppPalette.teal500,
    this.showLabel = false,
    this.useAsset = true,
  });

  /// Icon/asset diameter in logical pixels.
  final double size;

  /// Tint colour – defaults to the SeaPass brand teal.
  final Color color;

  /// When true, renders the "SeaPass" text label below the icon.
  final bool showLabel;

  /// When true, displays the official brand logo asset.
  final bool useAsset;

  @override
  Widget build(BuildContext context) {
    final Widget logoWidget = useAsset
        ? SvgPicture.asset(
            'assets/brand/seapass-mobile-logo.svg',
            width: size,
            height: size,
            fit: BoxFit.contain,

          )
        : Icon(
            MaterialCommunityIcons.ferry,
            size: size,
            color: color,
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        logoWidget,
        if (showLabel) ...[
          SizedBox(height: size * 0.14),
          Text(
            'SeaPass',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
