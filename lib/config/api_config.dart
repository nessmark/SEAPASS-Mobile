import 'dart:async';
import 'dart:io' show Platform, NetworkInterface, InternetAddressType, Socket;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Available connection targets for local testing and deployment.
enum ConnectionMode {
  /// Physical Android device connected via USB cable with `adb reverse tcp:8000 tcp:8000`.
  usbAdb('USB (ADB Reverse)', '127.0.0.1'),

  /// Android Studio / VS Code AVD emulator loopback alias.
  androidEmulator('Android Emulator', '10.0.2.2'),

  /// Automatically discovers and connects to the PC Laravel server over Wi-Fi.
  lanWifi('Wi-Fi (Auto-Connect Server)', '192.168.1.9'),

  /// Live production cloud server.
  production('Production Server', 'https://api.seapass.ph'),

  /// Custom user-specified endpoint.
  custom('Custom URL', '');

  const ConnectionMode(this.label, this.defaultHost);
  final String label;
  final String defaultHost;
}

class ApiConfig {
  const ApiConfig._();

  static const String _prefKeyBaseUrl = 'seapass_api_custom_base_url';
  static const String _prefKeyMode = 'seapass_api_connection_mode';

  /// Default port for the local Laravel API server.
  static const String defaultPort = '8000';

  /// Standard development host addresses
  static const String usbAdbHost = '127.0.0.1';
  static String lanWifiHost = '192.168.1.9';
  static const String emulatorHost = '10.0.2.2';
  static const String productionUrl = 'https://overplant-theology-chomp.ngrok-free.dev';

  // Build-time environment variable override:
  // flutter run --dart-define=SEAPASS_API_BASE_URL=https://api.example.com
  static const String _configuredBaseUrl = String.fromEnvironment(
    'SEAPASS_API_BASE_URL',
    defaultValue: '',
  );

  /// Normalises any user- or discovery-supplied base URL to the SITE ROOT.
  ///
  /// Every endpoint below appends its own `/api/...`, so a base that already ends
  /// in `/api` produced requests like `/api/api/login`. A field labelled "server
  /// URL" invites exactly that, so strip it here rather than trusting the input.
  static String normaliseBase(String url) {
    var clean = url.trim();
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    if (clean.toLowerCase().endsWith('/api')) {
      clean = clean.substring(0, clean.length - 4);
    }
    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  static String customBaseUrl = '';
  static ConnectionMode currentMode = ConnectionMode.lanWifi;

  /// Initialize and load any saved custom base URL and mode from persistent storage.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load saved mode
      final savedModeStr = prefs.getString(_prefKeyMode);
      if (savedModeStr != null) {
        currentMode = ConnectionMode.values.firstWhere(
          (m) => m.name == savedModeStr,
          orElse: () => ConnectionMode.lanWifi,
        );
      }

      // Load saved custom base URL
      final saved = prefs.getString(_prefKeyBaseUrl);
      if (saved != null && saved.trim().isNotEmpty) {
        customBaseUrl = normaliseBase(saved);
        // Repair a base saved by an older build that kept the trailing /api.
        if (customBaseUrl != saved.trim()) {
          await prefs.setString(_prefKeyBaseUrl, customBaseUrl);
        }
        try {
          final uri = Uri.parse(customBaseUrl);
          if (uri.host.isNotEmpty && uri.host != usbAdbHost && uri.host != emulatorHost) {
            lanWifiHost = uri.host;
          }
        } catch (_) {}
      }
    } catch (_) {
      // Graceful fallback to default baseUrl if storage read fails
    }
  }

  /// Switch the active connection mode dynamically at runtime and persist.
  static Future<void> setConnectionMode(ConnectionMode mode, {String? customHostOrUrl}) async {
    currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyMode, mode.name);

    switch (mode) {
      case ConnectionMode.usbAdb:
        await setCustomBaseUrl('http://$usbAdbHost:$defaultPort');
        break;
      case ConnectionMode.androidEmulator:
        await setCustomBaseUrl('http://$emulatorHost:$defaultPort');
        break;
      case ConnectionMode.lanWifi:
        final host = (customHostOrUrl != null && customHostOrUrl.trim().isNotEmpty)
            ? customHostOrUrl.trim()
            : lanWifiHost;
        lanWifiHost = host;
        await setCustomBaseUrl('http://$host:$defaultPort');
        break;
      case ConnectionMode.production:
        await setCustomBaseUrl(productionUrl);
        break;
      case ConnectionMode.custom:
        if (customHostOrUrl != null && customHostOrUrl.trim().isNotEmpty) {
          await setCustomBaseUrl(customHostOrUrl.trim());
        }
        break;
    }
  }

  /// Persist a custom base URL at runtime.
  static Future<void> setCustomBaseUrl(String url) async {
    customBaseUrl = normaliseBase(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (customBaseUrl.isEmpty) {
        await prefs.remove(_prefKeyBaseUrl);
      } else {
        await prefs.setString(_prefKeyBaseUrl, customBaseUrl);
      }
    } catch (_) {}
  }

  /// Quick helper to switch to USB ADB Reverse mode.
  static Future<void> useUsbAdb() async {
    await setConnectionMode(ConnectionMode.usbAdb);
  }

  /// Quick helper to switch to Android Emulator mode (10.0.2.2).
  static Future<void> useEmulator() async {
    await setConnectionMode(ConnectionMode.androidEmulator);
  }

  /// Quick helper to switch to LAN Wi-Fi mode.
  static Future<void> useLanWifi([String? host]) async {
    await setConnectionMode(ConnectionMode.lanWifi, customHostOrUrl: host);
  }

  /// Quick helper to switch to Production mode.
  static Future<void> useProduction() async {
    await setConnectionMode(ConnectionMode.production);
  }

  /// Computes the best alternate local fallback URL when primary connection fails.
  /// If currently attempting Wi-Fi LAN, the alternate is USB ADB Reverse (127.0.0.1).
  /// If currently attempting USB ADB, the alternate is Wi-Fi LAN (192.168.1.9).
  static String get fallbackBaseUrl {
    final active = baseUrl;
    if (active.contains(usbAdbHost) || active.contains(emulatorHost)) {
      return 'http://$lanWifiHost:$defaultPort';
    }
    return 'http://$usbAdbHost:$defaultPort';
  }

  /// Seamlessly switches between USB ADB and Wi-Fi LAN modes and persists the change.
  static Future<String> switchToFallback() async {
    final target = fallbackBaseUrl;
    if (target.contains(usbAdbHost)) {
      await useUsbAdb();
    } else {
      await useLanWifi();
    }
    return baseUrl;
  }

  /// Probes whether a given base URL is currently reachable by hitting the Laravel health or fares endpoint.
  static Future<bool> testConnection(String candidateBaseUrl, {Duration timeout = const Duration(seconds: 3)}) async {
    final cleanUrl = normaliseBase(candidateBaseUrl);

    // Test health endpoint (/up) first, then public fares endpoint (/api/fares)
    for (final path in ['/up', '/api/fares']) {
      try {
        final uri = Uri.parse('$cleanUrl$path');
        final response = await http.get(uri).timeout(timeout);
        if (response.statusCode >= 200 && response.statusCode < 400) {
          return true;
        }
      } catch (_) {
        // Continue to next probe path or fail
      }
    }
    return false;
  }

  /// Automatically discovers and connects to the active SeaPass Laravel server on the local network or USB.
  /// Checks:
  /// 1. Current host (e.g. 192.168.1.9:8000)
  /// 2. USB ADB reverse (127.0.0.1:8000)
  /// 3. Subnet scan across local Wi-Fi (192.168.1.2 - 35, 100 - 125)
  static Future<String?> autoDiscoverLanServer({
    Duration socketTimeout = const Duration(milliseconds: 600),
  }) async {
    // 1. Check currently configured Wi-Fi target first
    if (await testConnection('http://$lanWifiHost:$defaultPort', timeout: const Duration(seconds: 1))) {
      await useLanWifi(lanWifiHost);
      return 'http://$lanWifiHost:$defaultPort';
    }

    // 2. Check USB ADB reverse if plugged in
    if (await testConnection('http://$usbAdbHost:$defaultPort', timeout: const Duration(milliseconds: 800))) {
      await useUsbAdb();
      return 'http://$usbAdbHost:$defaultPort';
    }

    // 3. Scan local Wi-Fi subnet
    String subnet = '192.168.1';
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && (addr.address.startsWith('192.168.') || addr.address.startsWith('10.') || addr.address.startsWith('172.'))) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              break;
            }
          }
        }
      }
    } catch (_) {}

    final candidateIps = <String>[];
    for (int i = 2; i <= 35; i++) {
      final ip = '$subnet.$i';
      if (ip != lanWifiHost) candidateIps.add(ip);
    }
    for (int i = 100; i <= 125; i++) {
      final ip = '$subnet.$i';
      if (ip != lanWifiHost) candidateIps.add(ip);
    }

    const batchSize = 10;
    for (int i = 0; i < candidateIps.length; i += batchSize) {
      final end = (i + batchSize < candidateIps.length) ? i + batchSize : candidateIps.length;
      final batch = candidateIps.sublist(i, end);

      final futures = batch.map((ip) async {
        try {
          final socket = await Socket.connect(ip, int.parse(defaultPort), timeout: socketTimeout);
          socket.destroy();
          final isHealthy = await testConnection('http://$ip:$defaultPort', timeout: const Duration(seconds: 1));
          if (isHealthy) return ip;
        } catch (_) {}
        return null;
      });

      final results = await Future.wait(futures);
      for (final res in results) {
        if (res != null) {
          lanWifiHost = res;
          await useLanWifi(res);
          return 'http://$res:$defaultPort';
        }
      }
    }

    return null;
  }

  /// Automatically tests candidates (USB ADB Reverse & Wi-Fi LAN) and applies the first working one.
  static Future<ConnectionMode?> autoDetectConnection() async {
    final discovered = await autoDiscoverLanServer();
    if (discovered != null) {
      return currentMode;
    }
    return null;
  }

  /// Resolves the active base URL dynamically based on environment and runtime overrides.
  static String get baseUrl {
    // 1. Build-time --dart-define wins everywhere: it is the most explicit signal.
    if (_configuredBaseUrl.trim().isNotEmpty) {
      return normaliseBase(_configuredBaseUrl);
    }

    // 2. User runtime override (Settings sheet / Auto-Connect / SharedPreferences).
    //    This MUST be honoured in release too. It used to be skipped under
    //    kReleaseMode, which silently made the in-app "Server Connection
    //    Settings" sheet and Auto-Connect do nothing in any release build —
    //    every request went to productionUrl no matter what the user picked.
    if (customBaseUrl.trim().isNotEmpty) {
      return normaliseBase(customBaseUrl);
    }

    // 3. Release default: the deployed server.
    if (kReleaseMode) {
      return normaliseBase(productionUrl);
    }

    // 4. Web environment (browser runs on host computer)
    if (kIsWeb) {
      return 'http://127.0.0.1:$defaultPort';
    }

    // 5. Default Development Fallback for Android
    if (Platform.isAndroid) {
      // Default to USB ADB reverse. If testing wirelessly, call `useLanWifi()` or `useEmulator()`.
      return 'http://$usbAdbHost:$defaultPort';
    }

    // 6. Fallback for iOS / Desktop / Other
    return 'http://127.0.0.1:$defaultPort';
  }

  static String get passengerRegisterEndpoint =>
      '$baseUrl/api/passenger/register';

  static String get passengerSendOtpEndpoint =>
      '$baseUrl/api/passenger/send-otp';

  static String get passengerVerifyRegisterEndpoint =>
      '$baseUrl/api/passenger/verify-register';

  static String get passengerLoginEndpoint => '$baseUrl/api/passenger/login';
}
