import 'package:flutter/material.dart';
import 'app_palette.dart';

enum StatusTone { success, warning, danger, info }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = StatusTone.info, this.icon});
  final String label;
  final StatusTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      StatusTone.success => AppPalette.success,
      StatusTone.warning => AppPalette.warning,
      StatusTone.danger => AppPalette.danger,
      StatusTone.info => AppPalette.info,
    };
    final text = dark ? Color.lerp(color, AppPalette.white, .4)! : switch (tone) {
      StatusTone.success => AppPalette.successText,
      StatusTone.warning => AppPalette.warningText,
      StatusTone.danger => AppPalette.dangerText,
      StatusTone.info => AppPalette.teal700,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(AppPalette.radiusPill)),
      child: Text.rich(TextSpan(children: [
        if (icon != null) WidgetSpan(alignment: PlaceholderAlignment.middle,
          child: Padding(padding: const EdgeInsets.only(right: 4), child: Icon(icon, size: 14, color: text))),
        TextSpan(text: label),
      ]), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: text)),
    );
  }
}
