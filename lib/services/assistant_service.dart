import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../widgets/assistant/assistant_pages.dart';
import '../widgets/assistant/device_online.dart';
import 'api_service.dart';
import 'token_storage_service.dart';

/// Why the assistant cannot open right now. Each kind has its own screen state.
enum AssistantFailureKind {
  /// The phone has no network connection.
  offline,

  /// The SeaPass server did not answer or answered with a server error.
  unreachable,

  /// No session, or the session expired.
  signedOut,

  /// The server has no assistant provider configured.
  notConfigured,

  /// Anything else the server refused, with its own message.
  unavailable,
}

class AssistantUnavailable implements Exception {
  const AssistantUnavailable(this.kind, [this.detail]);

  final AssistantFailureKind kind;

  /// A server message for [AssistantFailureKind.unavailable]. Never a token or raw provider data.
  final String? detail;

  String get title => switch (kind) {
        AssistantFailureKind.offline => 'You are offline',
        AssistantFailureKind.unreachable => 'Cannot reach SeaPass',
        AssistantFailureKind.signedOut => 'Sign in to use the assistant',
        AssistantFailureKind.notConfigured => 'Assistant unavailable',
        AssistantFailureKind.unavailable => 'Assistant unavailable',
      };

  String get message => switch (kind) {
        AssistantFailureKind.offline => 'Connect to mobile data or Wi-Fi, then try again.',
        AssistantFailureKind.unreachable => 'The SeaPass server is not answering. Check your connection and try again.',
        AssistantFailureKind.signedOut => 'Your session has ended. Sign in again to chat with the assistant.',
        AssistantFailureKind.notConfigured => 'The assistant is switched off on the server right now. The page guide still works.',
        AssistantFailureKind.unavailable =>
          detail?.trim().isNotEmpty == true ? detail!.trim() : 'The assistant could not start. Try again in a moment.',
      };

  bool get canRetry => kind != AssistantFailureKind.signedOut && kind != AssistantFailureKind.notConfigured;

  @override
  String toString() => message;
}

typedef AssistantTokenReader = Future<String?> Function();

/// Authenticated assistant transport. Never retries a confirmed mutation automatically.
class AssistantService {
  static const statusTimeout = Duration(seconds: 15);

  /// Maps any transport error to a passenger-facing state.
  static AssistantUnavailable classify(Object error, {bool? online}) {
    if (error is AssistantUnavailable) return error;
    if (online == false) return const AssistantUnavailable(AssistantFailureKind.offline);
    if (error is TimeoutException) return const AssistantUnavailable(AssistantFailureKind.unreachable);
    if (error is SocketException) {
      final text = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
      final code = error.osError?.errorCode;
      final noNetwork = text.contains('failed host lookup') ||
          text.contains('network is unreachable') ||
          text.contains('no address associated') ||
          code == 7 ||
          code == 101;
      return AssistantUnavailable(noNetwork ? AssistantFailureKind.offline : AssistantFailureKind.unreachable);
    }
    if (error is http.ClientException) return const AssistantUnavailable(AssistantFailureKind.unreachable);
    return const AssistantUnavailable(AssistantFailureKind.unavailable);
  }

  static Future<Map<String, dynamic>> request(String endpoint, [Map<String, dynamic>? body, http.Client? client]) async {
    final uri = ApiService.buildUri(ApiService.baseUrl, '/api/assistant/$endpoint');
    final headers = await ApiService.buildHeaders();
    final http.Response response;
    try {
      if (client != null) {
        response = body == null
            ? await client.get(uri, headers: headers).timeout(statusTimeout)
            : await client.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 90));
      } else {
        response = body == null
            ? await http.get(uri, headers: headers).timeout(statusTimeout)
            : await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 90));
      }
    } catch (error) {
      throw classify(error, online: isDeviceOnline());
    }
    if (response.statusCode == 401) {
      // Same expiry handling as every other passenger request: clear the session
      // and return to sign in. The sheet shows its own signed-out state meanwhile.
      try {
        await ApiService.handleResponse(response);
      } catch (_) {}
      throw const AssistantUnavailable(AssistantFailureKind.signedOut);
    }
    Map<String, dynamic> data = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {}
    if (response.statusCode == 503) {
      throw AssistantUnavailable(AssistantFailureKind.unavailable, data['message']?.toString());
    }
    if (response.statusCode >= 500) {
      throw const AssistantUnavailable(AssistantFailureKind.unreachable);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AssistantUnavailable(AssistantFailureKind.unavailable, data['message']?.toString());
    }
    return data;
  }

  /// Context sent with every message: which screen, what it shows, and the
  /// guide targets really rendered on it.
  static Map<String, dynamic> pageContext({
    required String label,
    required String path,
    String? details,
    Iterable<String>? mountedTargets,
  }) {
    final targets = assistantTargetsFor(path, mounted: mountedTargets);
    final screen = assistantPage(path)?.label ?? label;
    final extra = details == null || details.trim().isEmpty ? '' : ' On screen: ${details.trim()}';
    return {
      'label': label,
      'path': path,
      'targets': targets,
      'text': 'Passenger app. Current screen: $screen.$extra'
          ' Available guide targets: ${targets.map((t) => t['id']).join(', ')}.'
          ' Host app handles current-screen guidance. The passenger selects seats and taps Pay; never claim a booking or payment was made.',
    };
  }

  static Future<Map<String, dynamic>> bootstrap({
    required String label,
    required String path,
    String theme = 'light',
    String? details,
    Iterable<String>? mountedTargets,
    http.Client? client,
    AssistantTokenReader? readToken,
  }) async {
    final token = await (readToken ?? TokenStorageService.getToken)();
    if (token == null || token.trim().isEmpty || token == 'null') {
      throw const AssistantUnavailable(AssistantFailureKind.signedOut);
    }
    final status = await request('status', null, client);
    if (status['configured'] == false) {
      throw const AssistantUnavailable(AssistantFailureKind.notConfigured);
    }
    final identity = status['identity'];
    // The embedded page refuses to start without an identity, so a missing one
    // would otherwise leave the passenger looking at an empty panel.
    if (identity == null || identity.toString().isEmpty) {
      throw const AssistantUnavailable(AssistantFailureKind.signedOut);
    }
    return {
      'token': token,
      'theme': theme,
      'identity': identity,
      'context': pageContext(label: label, path: path, details: details, mountedTargets: mountedTargets),
    };
  }

  static Uri get embedUri {
    final base = Uri.parse(ApiService.baseUrl);
    final path = base.path.replaceFirst(RegExp(r'/api/?$'), '');
    return base.replace(path: '$path/assistant/embed', query: null, fragment: null);
  }
}
