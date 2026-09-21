import 'package:flutter/material.dart';
import 'app_palette.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({super.key, required this.icon, required this.title,
    required this.caption, required this.actionLabel, required this.onAction});
  final IconData icon;
  final String title;
  final String caption;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 36, backgroundColor: AppColors.of(context).dark ? AppPalette.teal900 : AppPalette.teal100,
        child: Icon(icon, size: 40, color: AppColors.of(context).accent)),
      const SizedBox(height: 20),
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(caption, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 24),
      FilledButton(onPressed: onAction, child: Text(actionLabel)),
    ]),
  );
}
