import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class AssistantSurface extends StatefulWidget {
  final Uri uri;
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onEvent;
  const AssistantSurface({super.key, required this.uri, required this.config, required this.onEvent});
  @override
  State<AssistantSurface> createState() => _AssistantSurfaceState();
}
class _AssistantSurfaceState extends State<AssistantSurface> {
  late final web.HTMLIFrameElement _frame;
  late final String _view;
  late final JSFunction _listener;
  @override
  void initState() {
    super.initState();
    _view = 'seapass-assistant-${DateTime.now().microsecondsSinceEpoch}';
    _frame = web.HTMLIFrameElement()
      ..src = widget.uri.toString()
      ..title = 'SeaPass assistant'
      ..allow = 'microphone; clipboard-write'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(_view, (int id) => _frame);
    _listener = ((web.MessageEvent event) {
      // Dart equality dispatch reads properties on WindowProxy, which is forbidden
      // across origins. JavaScript strict equality compares the proxies safely.
      if (event.origin != widget.uri.origin || !event.source.strictEquals(_frame.contentWindow).toDart) return;
      final data = event.data.dartify();
      if (data is! Map || data['source'] != 'seapass-assistant') return;
      if (data['type'] == 'ready') {
        _frame.contentWindow?.postMessage({'type': 'seapass-bootstrap', ...widget.config}.jsify(), widget.uri.origin.toJS);
      } else {
        widget.onEvent(Map<String, dynamic>.from(data));
      }
    }).toJS;
    web.window.addEventListener('message', _listener);
  }
  @override
  void dispose() {
    web.window.removeEventListener('message', _listener);
    _frame.src = 'about:blank';
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _view);
}
