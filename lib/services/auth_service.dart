import 'dart:convert';

import 'api_exception.dart';
import 'api_service.dart';
import 'passenger_session.dart';
import 'token_storage_service.dart';

/// Centralized authentication service for passenger sign-up, OTP verification, login, and session.
class AuthService {
  const AuthService();

  /// Send a 6-digit OTP code to the passenger's email address.
  static Future<String> sendOtp({required String email}) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final response = await ApiService.post(
        '/api/passenger/send-otp',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': cleanEmail}),
        requiresAuth: false,
      );

      final dynamic decoded = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final message = decoded is Map<String, dynamic>
            ? decoded['message']?.toString()
            : null;
        return message ?? 'A 6-digit OTP code has been sent to $cleanEmail.';
      }

      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is Map) {
          final errs = errors.values.expand((e) => e is List ? e : [e]).join('\n');
          throw ApiException(errs);
        }
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw ApiException(message);
        }
      }

      throw ApiException('Failed to send verification code. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to server: $e');
    }
  }

  /// Verify the 6-digit OTP code and complete passenger registration.
  /// On success, automatically persists the Sanctum token and updates [PassengerSession].
  static Future<Map<String, dynamic>> verifyAndRegister({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String otp,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPhone = phone.trim();
    final cleanOtp = otp.trim();

    try {
      final response = await ApiService.post(
        '/api/passenger/verify-register',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': cleanName,
          'email': cleanEmail,
          'phone': cleanPhone,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'otp': cleanOtp,
        }),
        requiresAuth: false,
      );

      final dynamic decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> payload = {};
        if (decoded is Map<String, dynamic> && decoded['data'] is Map<String, dynamic>) {
          payload = Map<String, dynamic>.from(decoded['data']);
        } else if (decoded is Map<String, dynamic>) {
          payload = Map<String, dynamic>.from(decoded);
        }

        final token = payload['token']?.toString() ??
            (decoded is Map<String, dynamic> ? decoded['token']?.toString() : null);

        if (token != null && token.isNotEmpty) {
          await TokenStorageService.saveToken(token);
        }

        PassengerSession.name = payload['name']?.toString() ?? cleanName;
        PassengerSession.email = payload['email']?.toString() ?? cleanEmail;
        PassengerSession.phone = payload['phone']?.toString() ?? cleanPhone;
        PassengerSession.passengerId =
            int.tryParse(payload['id']?.toString() ?? '0') ?? 0;

        return payload;
      }

      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is Map) {
          final errs = errors.values.expand((e) => e is List ? e : [e]).join('\n');
          throw ApiException(errs);
        }
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw ApiException(message);
        }
      }

      throw ApiException('Registration failed. Please check your verification code.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to server: $e');
    }
  }

  /// Log in with email and password, saving the Sanctum auth token.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final response = await ApiService.post(
        '/api/passenger/login',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': cleanEmail, 'password': password}),
        requiresAuth: false,
      );

      final dynamic decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final payload = (decoded is Map<String, dynamic> &&
                decoded['data'] is Map<String, dynamic>)
            ? Map<String, dynamic>.from(decoded['data'])
            : (decoded is Map<String, dynamic>
                ? decoded
                : <String, dynamic>{});

        PassengerSession.name = payload['name']?.toString() ?? '';
        PassengerSession.email = payload['email']?.toString() ?? '';
        PassengerSession.phone = payload['phone']?.toString() ?? '';
        PassengerSession.passengerId =
            int.tryParse(payload['id']?.toString() ?? '0') ?? 0;

        final token = payload['token']?.toString() ??
            (decoded is Map<String, dynamic> ? decoded['token']?.toString() : null);
        if (token != null && token.isNotEmpty) {
          await TokenStorageService.saveToken(token);
          ApiService.setAuthToken(token);
        }

        return payload;
      }

      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      throw ApiException(message ?? 'Invalid email or password.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Could not connect to server: $e');
    }
  }

  /// Revoke current Sanctum token and clear passenger session.
  static Future<void> logout() async {
    try {
      await ApiService.post('/api/passenger/logout', requiresAuth: true);
    } catch (_) {
      // Ignore network errors during logout
    } finally {
      ApiService.clearAuthHeader();
      await TokenStorageService.deleteToken();
      PassengerSession.clear();
    }
  }
}
