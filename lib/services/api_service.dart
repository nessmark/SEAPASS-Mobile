import 'dart:async';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../app_navigator.dart';
import '../config/api_config.dart';
import '../screens/login_screen.dart';
import 'api_exception.dart';
import 'passenger_session.dart';
import 'token_storage_service.dart';

/// Centralized API service helper with Bearer token injection and 401 Unauthorized handling.
class ApiService {
  ApiService._();

  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 10);

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
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await TokenStorageService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  /// Handles response validation and intercepts 401 Unauthorized errors.
  static Future<http.Response> handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      // 1. Wipe encrypted token and in-memory passenger session
      await TokenStorageService.deleteToken();
      PassengerSession.clear();

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

      return await handleResponse(response);
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
}
