import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Icon in a tinted circle, a title, one line of caption and an optional action.
/// Never a bare "No data".
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.icon, required this.title,
    required this.caption, this.actionLabel, this.onAction, this.tone});
  final IconData icon;
  final String title;
  final String caption;
  final String? actionLabel;
  final VoidCallback? onAction;
  /// Optional semantic tint (warning / danger) for the icon circle.
  final Color? tone;
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final accent = tone ?? colors.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 36,
          backgroundColor: tone == null
            ? (colors.dark ? AppPalette.teal900 : AppPalette.teal100)
            : accent.withValues(alpha: .12),
          child: Icon(icon, size: 40, color: accent)),
        const SizedBox(height: AppPalette.space20),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppPalette.space8),
        Text(caption, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: AppPalette.space24),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ]),
    );
  }
}
