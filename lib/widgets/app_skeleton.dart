import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'app_card.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key, this.width, this.height = 18, this.radius = AppPalette.radiusSm});
  final double? width;
  final double height;
  final double radius;
  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}
class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: AppPalette.shimmerDuration);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) { _controller.stop(); } else { _controller.repeat(); }
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AnimatedBuilder(animation: _controller, builder: (context, _) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(widget.radius),
        color: colors.surface2,
        gradient: MediaQuery.disableAnimationsOf(context) ? null : LinearGradient(
          begin: Alignment(-3 + _controller.value * 4, 0), end: Alignment(-1 + _controller.value * 4, 0),
          colors: [colors.surface2, colors.hairline, colors.surface2], stops: const [0, .5, 1])),
    ));
  }
}

class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.count = 3});
  final int count;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(children: List.generate(count, (_) => const AppCard(
      margin: EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppSkeleton(width: 160, height: 24), SizedBox(height: 16),
        AppSkeleton(), SizedBox(height: 8), AppSkeleton(width: 120),
      ]),
    ))),
  );
}
