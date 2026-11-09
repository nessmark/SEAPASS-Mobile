import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'assistant_permissions.dart';

/// Native (Android) host for the Laravel assistant page.
///
/// Reports `ready` once the page has its session, and `surface_error` when it
/// cannot load, so the sheet can show one clear state with a retry.
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
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _fail(String reason) {
    if (_failed || !mounted) return;
    _failed = true;
    widget.onEvent({'type': 'surface_error', 'reason': reason});
  }

  Future<void> _initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fail('unsupported'));
      return;
    }
    late final WebViewController controller;
    controller = WebViewController(onPermissionRequest: (request) async {
      // Microphone only, only while our own assistant page is loaded, and only
      // after the passenger allows it at the OS prompt.
      final allowed = shouldGrantAssistantMedia(
        requested: request.types.map((type) => type.name),
        currentUrl: Uri.tryParse(await controller.currentUrl() ?? ''),
        assistantUri: widget.uri,
      );
      if (!allowed) {
        await request.deny();
        return;
      }
      final granted = await Permission.microphone.request().isGranted;
      if (granted) {
        await request.grant();
      } else {
        await request.deny();
      }
    });
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.addJavaScriptChannel('SeaPassHost', onMessageReceived: (message) async {
      try {
        final data = jsonDecode(message.message) as Map<String, dynamic>;
        if (data['source'] != 'seapass-assistant') return;
        if (data['type'] == 'ready') {
          await controller.runJavaScript('window.SeaPassAssistantBootstrap(${jsonEncode(widget.config)})');
          if (mounted) widget.onEvent({'source': 'seapass-assistant', 'type': 'ready'});
        } else if (data['type'] == 'save_pdf') {
          await FilePicker.platform.saveFile(
              dialogTitle: 'Save SeaPass report',
              fileName: data['name'] as String,
              type: FileType.custom,
              allowedExtensions: ['pdf'],
              bytes: base64Decode(data['data'] as String));
        } else if (mounted) {
          widget.onEvent(data);
        }
      } catch (_) {/* Never expose a token or raw provider data in diagnostics. */}
    });
    await controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) => isAssistantNavigationAllowed(request.url, widget.uri)
          ? NavigationDecision.navigate
          : NavigationDecision.prevent,
      onHttpError: (error) {
        // Only the assistant page itself counts. A failed image or script is
        // handled by the page.
        final code = error.response?.statusCode ?? 0;
        final url = error.request?.uri;
        if (code >= 400 && url != null && url.path == widget.uri.path) _fail('load_failed');
      },
      onWebResourceError: (error) {
        if (error.isForMainFrame == true) _fail('load_failed');
      },
    ));
    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      await android.setMediaPlaybackRequiresUserGesture(false);
      await android.setOnShowFileSelector((params) async {
        final files = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: assistantPickerExtensions(params.acceptTypes),
            allowMultiple: params.mode == FileSelectorMode.openMultiple);
        return files?.paths.whereType<String>().map((path) => File(path).uri.toString()).toList() ?? <String>[];
      });
    }
    await controller.loadRequest(widget.uri);
    if (mounted) setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _failed) return const SizedBox.shrink();
    return WebViewWidget(controller: _controller!);
  }

  @override
  void dispose() {
    // Lets the page stop voice capture and save the chat before it goes away.
    _controller?.runJavaScript('window.dispatchEvent(new Event("pagehide"))');
    super.dispose();
  }
}
