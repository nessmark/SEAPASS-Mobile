import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class AssistantSurface extends StatefulWidget {
  final Uri uri;
  final Map<String, dynamic> config;
  final ValueChanged<Map<String, dynamic>> onEvent;
  const AssistantSurface({super.key, required this.uri, required this.config, required this.onEvent});
  @override
  State<AssistantSurface> createState() => _AssistantSurfaceState();
}
class _AssistantSurfaceState extends State<AssistantSurface> {
  WebViewController? _controller;
  String? _error;
  @override
  void initState() { super.initState(); _initialize(); }
  Future<void> _initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) { setState(() => _error = 'Use the SeaPass web app for assistant access on this device.'); return; }
    final controller = WebViewController(onPermissionRequest: (request) async {
      // The only loaded origin is our own assistant page. Ask the OS before granting the mic.
      final granted = await Permission.microphone.request().isGranted;
      if (granted) { request.grant(); } else { request.deny(); }
    });
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.addJavaScriptChannel('SeaPassHost', onMessageReceived: (message) async {
      try {
        final data = jsonDecode(message.message) as Map<String, dynamic>;
        if (data['source'] != 'seapass-assistant') return;
        if (data['type'] == 'ready') {
          await controller.runJavaScript('window.SeaPassAssistantBootstrap(${jsonEncode(widget.config)})');
        } else if (data['type'] == 'save_pdf') {
          await FilePicker.platform.saveFile(dialogTitle: 'Save SeaPass report', fileName: data['name'] as String, type: FileType.custom, allowedExtensions: ['pdf'], bytes: base64Decode(data['data'] as String));
        } else { widget.onEvent(data); }
      } catch (_) { /* Never expose a token or raw provider data in diagnostics. */ }
    });
    await controller.setNavigationDelegate(NavigationDelegate(onNavigationRequest: (request) {
      final destination = Uri.tryParse(request.url);
      return destination?.origin == widget.uri.origin ? NavigationDecision.navigate : NavigationDecision.prevent;
    }, onWebResourceError: (error) { if (error.isForMainFrame == true && mounted) setState(() => _error = 'The assistant could not load. Check your server connection and try again.'); }));
    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
      await android.setOnShowFileSelector((params) async {
        final files = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf', 'txt'], allowMultiple: true);
        return files?.paths.whereType<String>().map((path) => File(path).uri.toString()).toList() ?? <String>[];
      });
    }
    await controller.loadRequest(widget.uri);
    if (mounted) setState(() => _controller = controller);
  }
  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    if (_controller == null) return const Center(child: CircularProgressIndicator());
    return WebViewWidget(controller: _controller!);
  }
  @override
  void dispose() { _controller?.runJavaScript('window.dispatchEvent(new Event("pagehide"))'); super.dispose(); }
}
