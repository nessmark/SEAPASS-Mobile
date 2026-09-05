import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

/// The canonical SeaPass logo widget used across the entire app.
///
/// Renders the official brand ferry image asset (`assets/images/logo.png`)
/// with fallback to the MaterialCommunityIcons ferry icon.
class SeaPassLogo extends StatelessWidget {
  const SeaPassLogo({
    super.key,
    this.size = 72,
    this.color = const Color(0xFF6BBF9E),
    this.showLabel = false,
    this.useAsset = true,
  });

  /// Icon/asset diameter in logical pixels.
  final double size;

  /// Tint colour – defaults to the SeaPass mint green.
  final Color color;

  /// When true, renders the "SeaPass" text label below the icon.
  final bool showLabel;

  /// When true, displays the official brand logo asset.
  final bool useAsset;

  @override
  Widget build(BuildContext context) {
    final Widget logoWidget = useAsset
        ? Image.asset(
            'assets/images/logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              MaterialCommunityIcons.ferry,
              size: size,
              color: color,
            ),
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
