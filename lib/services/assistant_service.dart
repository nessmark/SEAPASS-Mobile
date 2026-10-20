import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'token_storage_service.dart';

/// Authenticated assistant transport. Never retries a confirmed mutation automatically.
class AssistantService {
  static Future<Map<String, dynamic>> request(String endpoint, [Map<String, dynamic>? body]) async {
    final uri = ApiService.buildUri(ApiService.baseUrl, '/api/assistant/$endpoint');
    final headers = await ApiService.buildHeaders();
    final response = body == null
        ? await http.get(uri, headers: headers).timeout(const Duration(seconds: 15))
        : await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 90));
    await ApiService.handleResponse(response);
    final dynamic decoded = jsonDecode(response.body);
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? 'SeaPass assistant could not connect. Please try again.');
    }
    return data;
  }

  static Future<Map<String, dynamic>> bootstrap({
    required String label,
    required String path,
    String theme = 'light',
  }) async {
    final status = await request('status');
    final token = await TokenStorageService.getToken();
    if (token == null || token.isEmpty) throw Exception('Sign in again to use your SeaPass assistant.');
    final targets = _targetsForPage(path);
    return {
      'token': token,
      'theme': theme,
      'identity': status['identity'],
      'context': {
        'label': label,
        'path': path,
        'targets': targets,
        'text': 'Passenger app. Current screen: $label. Available guide targets: ${targets.map((t) => t['id']).join(', ')}. Host app handles current-screen guidance.',
      },
    };
  }

  static List<Map<String, dynamic>> _targetsForPage(String page) => switch (page) {
    'trips' => [
      {'id': 'route_selector', 'label': 'Route & Port Selector', 'description': 'Choose origin and destination ports'},
      {'id': 'date_rail', 'label': 'Travel Date Rail', 'description': 'Select departure date across 21 days'},
      {'id': 'schedules_list', 'label': 'Scheduled Sailings', 'description': 'Departure times, boat names and available seats'},
    ],
    'bookings' => [
      {'id': 'tabs', 'label': 'Booking Status Filter', 'description': 'Toggle between pending review and confirmed tickets'},
      {'id': 'booking_card', 'label': 'Booking Cards', 'description': 'Open boarding passes and view ticket QR codes'},
    ],
    'advisories' => [
      {'id': 'advisories_list', 'label': 'Notice Board', 'description': 'Active port notices and sea condition bulletins'},
    ],
    'profile' => [
      {'id': 'profile_card', 'label': 'Passenger Profile', 'description': 'View verified passenger details and contact number'},
      {'id': 'account_settings', 'label': 'Account Settings', 'description': 'Update name, mobile number and change password'},
      {'id': 'travel_history', 'label': 'Travel History', 'description': 'Archive of completed voyages'},
    ],
    _ => [],
  };

  static Uri get embedUri {
    final base = Uri.parse(ApiService.baseUrl);
    final path = base.path.replaceFirst(RegExp(r'/api/?$'), '');
    return base.replace(path: '$path/assistant/embed', query: null, fragment: null);
  }
}
