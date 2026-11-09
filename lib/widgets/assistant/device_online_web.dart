import 'package:web/web.dart' as web;

/// The browser's own connectivity flag.
bool? isDeviceOnline() => web.window.navigator.onLine;
