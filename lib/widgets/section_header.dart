import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.caption, this.action, this.large = false});
  final String title;
  final String? caption;
  final Widget? action;
  final bool large;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: large ? Theme.of(context).textTheme.headlineLarge : Theme.of(context).textTheme.headlineMedium),
        if (caption != null) ...[const SizedBox(height: 8), Text(caption!, style: Theme.of(context).textTheme.bodySmall)],
      ])),
      if (action != null) action!,
    ]),
  );
}
