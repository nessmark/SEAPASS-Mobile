import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../app_navigator.dart';
import '../config/api_config.dart';
import '../screens/login_screen.dart';
import 'api_exception.dart';
import 'passenger_session.dart';
import 'token_storage_service.dart';

/// Centralized API service helper with Bearer token injection, persistent Base URL, and 401 handling.
class ApiService {
  ApiService._();

  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 10);

  /// Active Base URL - retains its configured endpoint across logins and logouts.
  static String get baseUrl => ApiConfig.baseUrl;

  /// Default headers map preserved across the client singleton lifecycle.
  static final Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'ngrok-skip-browser-warning': 'true',
  };

  /// Attach the new Bearer <token> to the existing ApiService client on login without re-initializing network service.
  static void setAuthToken(String token) {
    if (token.isNotEmpty) {
      _defaultHeaders['Authorization'] = 'Bearer $token';
    }
  }

  /// When a user logs out: Keep baseUrl intact, only clear request authorization header.
  static void clearAuthHeader() {
    _defaultHeaders.remove('Authorization');
  }

  /// Ensure ApiService reads and initializes saved api_base_url from local storage during app launch.
  static Future<void> init() async {
    await ApiConfig.init();
    final token = await TokenStorageService.getToken();
    if (token != null && token.isNotEmpty) {
      setAuthToken(token);
    } else {
      clearAuthHeader();
    }
  }

  /// Builds a Uri pointing to the active API base URL.
  static Uri buildUri(String baseUrl, String endpoint, [Map<String, dynamic>? queryParameters]) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$base$cleanEndpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      return uri.replace(queryParameters: queryParameters);
    }
    return uri;
  }

  /// Injects standard JSON headers and Bearer token if available / requested.
  static Future<Map<String, String>> buildHeaders({
    Map<String, String>? customHeaders,
    bool requiresAuth = true,
  }) async {
    final headers = Map<String, String>.from(_defaultHeaders);

    if (requiresAuth) {
      if (!headers.containsKey('Authorization')) {
        final token = await TokenStorageService.getToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
    } else {
      headers.remove('Authorization');
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  /// Handles response validation and intercepts 401 Unauthorized errors for authenticated sessions.
  static Future<http.Response> handleResponse(
    http.Response response, {
    bool requiresAuth = true,
  }) async {
    if (response.statusCode == 401 && requiresAuth) {
      // 1. Wipe only authorization header, retaining baseUrl intact
      clearAuthHeader();
      await TokenStorageService.deleteToken();
      await PassengerSession.clear();

      // 2. Headless redirect to login screen
      rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
        LoginScreen.routeName,
        (route) => false,
      );

      throw ApiException('Your session has expired or is unauthorized. Please sign in again.');
    }

    return response;
  }

  /// Sends an HTTP request with automatic fallback between Wi-Fi and USB ADB Reverse.
  static Future<http.Response> request({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final reqHeaders = await buildHeaders(customHeaders: headers, requiresAuth: requiresAuth);

    Future<http.Response> execute(Uri uri, Duration timeout) async {
      http.Response response;
      if (method.toUpperCase() == 'POST') {
        response = await _client.post(uri, headers: reqHeaders, body: body).timeout(timeout);
      } else if (method.toUpperCase() == 'PUT') {
        response = await _client.put(uri, headers: reqHeaders, body: body).timeout(timeout);
      } else if (method.toUpperCase() == 'DELETE') {
        response = await _client.delete(uri, headers: reqHeaders, body: body).timeout(timeout);
      } else {
        response = await _client.get(uri, headers: reqHeaders).timeout(timeout);
      }

      return await handleResponse(response, requiresAuth: requiresAuth);
    }

    final primaryUri = buildUri(ApiConfig.baseUrl, endpoint, queryParameters);

    try {
      return await execute(primaryUri, _timeout);
    } catch (firstError) {
      // If we encounter a network/socket or timeout error, attempt local alternate fallback
      if (firstError is TimeoutException || firstError is SocketException) {
        final fallbackBase = ApiConfig.fallbackBaseUrl;
        if (fallbackBase != ApiConfig.baseUrl) {
          final fallbackUri = buildUri(fallbackBase, endpoint, queryParameters);
          try {
            final fallbackResponse = await execute(fallbackUri, const Duration(seconds: 4));
            if (fallbackResponse.statusCode < 500) {
              await ApiConfig.switchToFallback();
              return fallbackResponse;
            }
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  /// Sends a multipart HTTP request (for file uploads) with automatic auth header injection and timeout.
  static Future<http.Response> multipartRequest({
    required String method,
    required String endpoint,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
    Map<String, String>? headers,
    bool requiresAuth = true,
  }) async {
    final reqHeaders = await buildHeaders(customHeaders: headers, requiresAuth: requiresAuth);
    reqHeaders.remove('Content-Type'); // Allow multipart boundary to be set automatically

    final uri = buildUri(ApiConfig.baseUrl, endpoint);
    final request = http.MultipartRequest(method.toUpperCase(), uri);
    request.headers.addAll(reqHeaders);

    if (fields != null) {
      request.fields.addAll(fields);
    }
    if (files != null) {
      request.files.addAll(files);
    }

    try {
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return await handleResponse(response, requiresAuth: requiresAuth);
    } catch (firstError) {
      if (firstError is TimeoutException || firstError is SocketException) {
        final fallbackBase = ApiConfig.fallbackBaseUrl;
        if (fallbackBase != ApiConfig.baseUrl) {
          final fallbackUri = buildUri(fallbackBase, endpoint);
          try {
            final fbReq = http.MultipartRequest(method.toUpperCase(), fallbackUri);
            fbReq.headers.addAll(reqHeaders);
            if (fields != null) fbReq.fields.addAll(fields);
            if (files != null) fbReq.files.addAll(files);
            final fbStream = await fbReq.send().timeout(const Duration(seconds: 4));
            final fbResp = await http.Response.fromStream(fbStream);
            if (fbResp.statusCode < 500) {
              await ApiConfig.switchToFallback();
              return await handleResponse(fbResp, requiresAuth: requiresAuth);
            }
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  /// Convenience GET helper.
  static Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request(
      method: 'GET',
      endpoint: endpoint,
      headers: headers,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  /// Convenience POST helper.
  static Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request(
      method: 'POST',
      endpoint: endpoint,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  /// Convenience DELETE helper.
  static Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return request(
      method: 'DELETE',
      endpoint: endpoint,
      headers: headers,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  /// Sends a 6-digit OTP code to the passenger email.
  static Future<http.Response> sendOtp({required String email}) {
    return post(
      '/api/passenger/send-otp',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: '{"email":"${email.trim().toLowerCase()}"}',
      requiresAuth: false,
    );
  }

  /// Dispatches passenger verification and registration payload.
  static Future<http.Response> verifyAndRegister({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String otp,
  }) {
    return post(
      '/api/passenger/verify-register',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: '{"name":"${name.trim()}","email":"${email.trim().toLowerCase()}","phone":"${phone.trim()}","password":"$password","password_confirmation":"$passwordConfirmation","otp":"${otp.trim()}"}',
      requiresAuth: false,
    );
  }
}
