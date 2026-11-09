import 'package:flutter/material.dart';

/// No system settings page to open on this platform.
Future<bool> openAssistantPermissionSettings() async => false;

/// Platforms without a web view. The sheet shows its own unavailable state.
class AssistantSurface extends StatefulWidget {
  final Uri uri;
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onEvent;
  const AssistantSurface({super.key, required this.uri, required this.config, required this.onEvent});
  @override
  State<AssistantSurface> createState() => _AssistantSurfaceState();
}

class _AssistantSurfaceState extends State<AssistantSurface> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onEvent({'type': 'surface_error', 'reason': 'unsupported'});
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
