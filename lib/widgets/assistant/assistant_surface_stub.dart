import 'package:flutter/material.dart';
class AssistantSurface extends StatelessWidget {
  final Uri uri;
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onEvent;
  const AssistantSurface({super.key, required this.uri, required this.config, required this.onEvent});
  @override
  Widget build(BuildContext context) => const Center(child: Text('SeaPass assistant is available on Android, iPhone and the web.'));
}
