import 'package:flutter/material.dart';
import 'app_palette.dart';

/// A softly elevated, borderless surface. Interactive cards share focus/hover feedback.
class AppCard extends StatefulWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(24),
    this.margin = EdgeInsets.zero, this.onTap, this.color, this.clipBehavior = Clip.none});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final Clip clipBehavior;
  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppPalette.radiusLg);
    return AnimatedScale(
      scale: _pressed ? .98 : 1, duration: AppPalette.duration(context), curve: AppPalette.motionCurve,
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(borderRadius: radius,
          boxShadow: AppPalette.shadows(Theme.of(context).brightness, level: _hovered ? 2 : 1)),
        child: Material(
          color: widget.color ?? AppColors.of(context).surface,
          borderRadius: radius, clipBehavior: widget.clipBehavior,
          child: CustomPaint(
            foregroundPainter: dark ? const _TopLight() : null,
            child: InkWell(
              onTap: widget.onTap, borderRadius: radius,
              onHover: (value) => setState(() => _hovered = value),
              onFocusChange: (value) => setState(() => _focused = value),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              hoverColor: AppPalette.teal500.withValues(alpha: .04),
              focusColor: AppPalette.teal500.withValues(alpha: .08),
              child: Container(
                foregroundDecoration: _focused ? BoxDecoration(borderRadius: radius,
                  border: Border.all(color: AppPalette.teal500.withValues(alpha: .24), width: 3)) : null,
                padding: widget.padding, child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopLight extends CustomPainter {
  const _TopLight();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(const Offset(20, .5), Offset(size.width - 20, .5),
      Paint()..color = AppPalette.darkTopEdge..strokeWidth = 1);
  }
  @override
  bool shouldRepaint(_TopLight oldDelegate) => false;
}
