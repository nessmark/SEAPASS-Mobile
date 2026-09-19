import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, File;

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/booking.dart';
import '../models/route_fare.dart';
import '../models/schedule.dart';
import '../utils/manila_clock.dart';
import 'api_exception.dart';
import 'api_service.dart';
import 'passenger_session.dart';
import 'token_storage_service.dart';

class PassengerDataService {
  const PassengerDataService();

  /// Centralized network exception mapper that returns clear, actionable diagnostic messages.
  static ApiException mapNetworkException(Object error, Uri uri) {
    if (error is ApiException) {
      return error;
    }
    final hostPort = uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
    if (error is TimeoutException) {
      return ApiException(
        'Connection to SeaPass server timed out ($hostPort).\n'
        '• If using USB debugging, run: adb reverse tcp:8000 tcp:8000\n'
        '• If using Wi-Fi, ensure phone and PC are on the same Wi-Fi and Laravel was started with: php artisan serve --host=0.0.0.0 --port=8000\n'
        '• Check that Windows Defender Firewall allows TCP port 8000 and turn off phone mobile data (4G/5G).',
      );
    }
    if (error is SocketException) {
      final detail = error.osError?.message ?? error.message;
      return ApiException(
        'Unable to reach SeaPass server at $hostPort ($detail).\n'
        '• If using USB debugging, run: adb reverse tcp:8000 tcp:8000\n'
        '• If using Wi-Fi, verify the PC IP address, ensure Laravel is running on 0.0.0.0, and check firewall settings.',
      );
    }
    if (error is http.ClientException) {
      return ApiException(
        'Network client error connecting to $hostPort: ${error.message}',
      );
    }
    return ApiException(
      'Could not connect to SeaPass server (${ApiConfig.baseUrl}): $error',
    );
  }

  /// Dispatches an HTTP request via the centralized ApiService, automatically injecting
  /// the Sanctum Bearer token and handling 401 Unauthorized redirect logic.
  Future<http.Response> _sendRequest({
    required String method,
    required String path,
    Map<String, String>? headers,
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    try {
      return await ApiService.request(
        method: method,
        endpoint: path,
        headers: headers,
        body: body,
        queryParameters: queryParameters,
        requiresAuth: requiresAuth,
      );
    } catch (firstError) {
      if (firstError is ApiException) rethrow;
      final uri = ApiService.buildUri(ApiConfig.baseUrl, path, queryParameters);
      throw mapNetworkException(firstError, uri);
    }
  }

  // ─── Authentication API ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _sendRequest(
        method: 'POST',
        path: '/api/login',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
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

        final role = payload['role']?.toString().toLowerCase() ?? 'passenger';
        final assignedPort = payload['assigned_port']?.toString();

        await PassengerSession.saveSession(
          name: payload['name']?.toString() ?? '',
          email: payload['email']?.toString() ?? '',
          phone: payload['phone']?.toString() ?? '',
          passengerId: int.tryParse(payload['id']?.toString() ?? '0') ?? 0,
          role: role,
          assignedPort: assignedPort,
        );

        // Persist encrypted Sanctum Bearer token in secure storage
        final token = payload['token']?.toString() ??
            (decoded is Map<String, dynamic> ? decoded['token']?.toString() : null);
        if (token != null && token.isNotEmpty) {
          await TokenStorageService.saveToken(token);
          ApiService.setAuthToken(token);
        }
        await TokenStorageService.saveUserRole(role);

        return payload;
      }

      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      throw ApiException(message ?? 'Invalid email or password.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw mapNetworkException(e, Uri.parse(ApiConfig.passengerLoginEndpoint));
    }
  }

  /// Verify booking ticket QR code for boarding (Scanner Staff API).
  Future<Map<String, dynamic>> verifyTicket(String codeOrReference) async {
    try {
      final response = await _sendRequest(
        method: 'POST',
        path: '/api/bookings/verify-ticket',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'reference_number': codeOrReference}),
        requiresAuth: true,
      );

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {
        'success': false,
        'status': 'UNKNOWN_RESPONSE',
        'message': 'Unexpected response received from ticket verification server.',
      };
    } catch (e) {
      if (e is ApiException) rethrow;
      final uri = ApiService.buildUri(ApiConfig.baseUrl, '/api/bookings/verify-ticket');
      throw mapNetworkException(e, uri);
    }
  }

  Future<String> sendOtp({required String email}) async {
    try {
      final response = await _sendRequest(
        method: 'POST',
        path: '/api/passenger/send-otp',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
        requiresAuth: false,
      );

      final dynamic decoded = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final msg = decoded is Map<String, dynamic>
            ? decoded['message']?.toString()
            : null;
        return msg ?? 'OTP sent to $email.';
      }

      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is Map) {
          final errs =
              errors.values.expand((e) => e is List ? e : [e]).join('\n');
          throw ApiException(errs);
        }
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw ApiException(message);
        }
      }
      throw ApiException('Failed to send OTP.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw mapNetworkException(e, Uri.parse(ApiConfig.passengerSendOtpEndpoint));
    }
  }

  Future<void> verifyAndRegister({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String otp,
  }) async {
    try {
      final response = await _sendRequest(
        method: 'POST',
        path: '/api/passenger/verify-register',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'password_confirmation': passwordConfirmation,
          'otp': otp,
        }),
        requiresAuth: false,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> &&
            decoded['data'] is Map<String, dynamic>) {
          final payload = Map<String, dynamic>.from(decoded['data']);
          PassengerSession.name = payload['name']?.toString() ?? name;
          PassengerSession.email = payload['email']?.toString() ?? email;
          PassengerSession.phone = payload['phone']?.toString() ?? phone;
          PassengerSession.passengerId =
              int.tryParse(payload['id']?.toString() ?? '0') ?? 0;

          // Persist encrypted Sanctum Bearer token in secure storage
          final token = payload['token']?.toString() ??
              (decoded['token']?.toString());
          if (token != null && token.isNotEmpty) {
            await TokenStorageService.saveToken(token);
          }
        } else {
          PassengerSession.name = name;
          PassengerSession.email = email;
          PassengerSession.phone = phone;
          if (decoded is Map<String, dynamic> && decoded['token'] != null) {
            await TokenStorageService.saveToken(decoded['token'].toString());
          }
        }
        return;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final errors = decoded['errors'];
        if (errors is Map) {
          final errs =
              errors.values.expand((e) => e is List ? e : [e]).join('\n');
          throw ApiException(errs);
        }
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          throw ApiException(message);
        }
      }
      throw ApiException('Registration failed. Please try again.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw mapNetworkException(e, Uri.parse(ApiConfig.passengerVerifyRegisterEndpoint));
    }
  }

  /// Revoke the current access token on the backend, wipe stored credentials and session.
  Future<void> logout() async {
    try {
      await _sendRequest(
        method: 'POST',
        path: '/api/logout',
        requiresAuth: true,
      );
    } catch (_) {
      // Gracefully continue even if offline
    } finally {
      ApiService.clearAuthHeader();
      await TokenStorageService.deleteToken();
      PassengerSession.clear();
    }
  }

  // ─── Schedule, Fare & Booking API ────────────────────────────────────────

  Future<List<Schedule>> fetchSchedules({
    required DateTime date,
    required String from,
    required String to,
  }) async {
    try {
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/schedules',
        queryParameters: {
          'date': ManilaClock.toQueryDate(date),
          'from': from,
          'to': to,
        },
        requiresAuth: false,
      );

      if (response.statusCode != 200) {
        throw ApiException('Unable to load schedules for the selected date.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const [];
      }

      final rawList = decoded['schedules'];
      if (rawList is! List) {
        return const [];
      }

      return excludeDepartedSchedules(
        rawList
            .whereType<Map>()
            .map((item) => Schedule.fromJson(Map<String, dynamic>.from(item)))
            .where((schedule) => schedule.matchesExactDate(date))
            .toList(),
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw mapNetworkException(e, Uri.parse('${ApiConfig.baseUrl}/api/schedules'));
    }
  }

  /// Fetch distinct dates that have bookable trips for the given route and month.
  Future<Set<DateTime>> fetchAvailableDates({
    required String from,
    required String to,
    String? month,
  }) async {
    try {
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/schedules/available-dates',
        queryParameters: {
          'from': from,
          'to': to,
          if (month != null) 'month': month,
        },
        requiresAuth: false,
      );

      if (response.statusCode != 200) {
        return const {};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const {};
      }

      final rawList = decoded['available_dates'];
      if (rawList is! List) {
        return const {};
      }

      final Set<DateTime> dates = {};
      for (final item in rawList) {
        if (item is String) {
          final parsed = DateTime.tryParse(item);
          if (parsed != null) {
            dates.add(DateTime(parsed.year, parsed.month, parsed.day));
          }
        }
      }
      return dates;
    } catch (_) {
      // Graceful fallback: return empty set on network error
      return const {};
    }
  }

  Future<RouteFare> fetchFareForRoute(
    String route, {
    String? from,
    String? to,
  }) async {
    try {
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/fares',
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
        queryParameters: {
          if (from != null && from.trim().isNotEmpty) 'from': from.trim(),
          if (to != null && to.trim().isNotEmpty) 'to': to.trim(),
          if (route.trim().isNotEmpty) 'route': route.trim(),
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        requiresAuth: false,
      );

      if (response.statusCode != 200) {
        throw ApiException('Unable to load live fares.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw ApiException('Unable to load live fares.');
      }

      return RouteFare.fromJson(decoded);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw mapNetworkException(e, Uri.parse('${ApiConfig.baseUrl}/api/fares'));
    }
  }

  Future<Map<String, dynamic>> fetchTripSeatMap(int scheduleId) async {
    try {
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/trips/$scheduleId/seat-map',
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
        requiresAuth: false,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<Booking> createBooking({
    required int scheduleId,
    required String passengerName,
    required int seatCount,
    required double amountCollected,
    required String notes,
    List<dynamic>? seatNumbers,
    List<dynamic>? seatBreakdown,
    Map<int, String>? passengerIdPhotos,
    int? passengerId,
    String? contactNumber,
    String? email,
  }) async {
    try {
      final List<http.MultipartFile> multipartFiles = [];
      if (passengerIdPhotos != null && passengerIdPhotos.isNotEmpty) {
        for (final entry in passengerIdPhotos.entries) {
          final filePath = entry.value;
          if (filePath.isNotEmpty) {
            final file = File(filePath);
            if (await file.exists()) {
              multipartFiles.add(
                await http.MultipartFile.fromPath(
                  'passenger_id_photos_${entry.key}',
                  filePath,
                ),
              );
            }
          }
        }
      }

      final http.Response response;
      if (multipartFiles.isNotEmpty) {
        final Map<String, String> fields = {
          'schedule_id': scheduleId.toString(),
          'passenger_name': passengerName,
          'seat_count': seatCount.toString(),
          'amount_collected': amountCollected.toString(),
          'notes': notes,
          if (seatNumbers != null && seatNumbers.isNotEmpty)
            'seat_numbers': jsonEncode(seatNumbers),
          if (seatBreakdown != null && seatBreakdown.isNotEmpty)
            'seat_breakdown': jsonEncode(seatBreakdown),
          if (passengerId != null && passengerId > 0)
            'passenger_id': passengerId.toString(),
          if (contactNumber != null && contactNumber.trim().isNotEmpty)
            'contact_number': contactNumber.trim(),
          if (email != null && email.trim().isNotEmpty)
            'email': email.trim(),
        };

        response = await ApiService.multipartRequest(
          method: 'POST',
          endpoint: '/api/passenger/bookings',
          fields: fields,
          files: multipartFiles,
        );
      } else {
        response = await _sendRequest(
          method: 'POST',
          path: '/api/passenger/bookings',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'schedule_id': scheduleId,
            'passenger_name': passengerName,
            'seat_count': seatCount,
            'amount_collected': amountCollected,
            'notes': notes,
            if (seatNumbers != null && seatNumbers.isNotEmpty)
              'seat_numbers': seatNumbers,
            if (seatBreakdown != null && seatBreakdown.isNotEmpty)
              'seat_breakdown': seatBreakdown,
            if (passengerId != null && passengerId > 0)
              'passenger_id': passengerId,
            if (contactNumber != null && contactNumber.trim().isNotEmpty)
              'contact_number': contactNumber.trim(),
            if (email != null && email.trim().isNotEmpty)
              'email': email.trim(),
          }),
        );
      }

      final decoded = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (decoded is Map<String, dynamic> && decoded['booking'] != null) {
          return Booking.fromJson(
              Map<String, dynamic>.from(decoded['booking']));
        }
        // API returned success but no booking data — surface the error
        throw ApiException('Booking submitted but no confirmation received. Please check My Bookings.');
      }

      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      throw ApiException(message ?? 'Unable to submit booking.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw mapNetworkException(e, Uri.parse('${ApiConfig.baseUrl}/api/passenger/bookings'));
    }
  }

  /// Initialize a PayMongo checkout session for dynamic GCash / QR Ph payment.
  /// Supports both new booking creation and payment for an existing booking.
  Future<Map<String, dynamic>> createPayMongoCheckoutSession({
    int? bookingId,
    int? scheduleId,
    String? passengerName,
    int? seatCount,
    double? amountCollected,
    String? notes,
    List<dynamic>? seatNumbers,
    List<dynamic>? seatBreakdown,
    Map<int, String>? passengerIdPhotos,
    int? passengerId,
    String? contactNumber,
    String? email,
  }) async {
    try {
      if (bookingId != null && bookingId > 0) {
        final response = await _sendRequest(
          method: 'POST',
          path: '/api/payments/checkout',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({'booking_id': bookingId}),
        );

        final dynamic decoded = jsonDecode(response.body);
        if (response.statusCode == 200 && decoded is Map<String, dynamic> && decoded['checkout_url'] != null) {
          return decoded;
        }

        final message = decoded is Map<String, dynamic> ? decoded['message']?.toString() : null;
        throw ApiException(message ?? 'Failed to initialize PayMongo checkout.');
      }

      final List<http.MultipartFile> multipartFiles = [];
      if (passengerIdPhotos != null && passengerIdPhotos.isNotEmpty) {
        for (final entry in passengerIdPhotos.entries) {
          final filePath = entry.value;
          if (filePath.isNotEmpty) {
            final file = File(filePath);
            if (await file.exists()) {
              multipartFiles.add(
                await http.MultipartFile.fromPath(
                  'passenger_id_photos_${entry.key}',
                  filePath,
                ),
              );
            }
          }
        }
      }

      final http.Response response;
      if (multipartFiles.isNotEmpty) {
        final Map<String, String> fields = {
          if (scheduleId != null) 'schedule_id': scheduleId.toString(),
          if (passengerName != null) 'passenger_name': passengerName,
          if (seatCount != null) 'seat_count': seatCount.toString(),
          if (amountCollected != null) 'amount_collected': amountCollected.toString(),
          if (notes != null) 'notes': notes,
          if (seatNumbers != null && seatNumbers.isNotEmpty)
            'seat_numbers': jsonEncode(seatNumbers),
          if (seatBreakdown != null && seatBreakdown.isNotEmpty)
            'seat_breakdown': jsonEncode(seatBreakdown),
          if (passengerId != null && passengerId > 0)
            'passenger_id': passengerId.toString(),
          if (contactNumber != null && contactNumber.trim().isNotEmpty)
            'contact_number': contactNumber.trim(),
          if (email != null && email.trim().isNotEmpty)
            'email': email.trim(),
        };

        response = await ApiService.multipartRequest(
          method: 'POST',
          endpoint: '/api/payments/checkout',
          fields: fields,
          files: multipartFiles,
        );
      } else {
        response = await _sendRequest(
          method: 'POST',
          path: '/api/payments/checkout',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            if (scheduleId != null) 'schedule_id': scheduleId,
            if (passengerName != null) 'passenger_name': passengerName,
            if (seatCount != null) 'seat_count': seatCount,
            if (amountCollected != null) 'amount_collected': amountCollected,
            if (notes != null) 'notes': notes,
            if (seatNumbers != null && seatNumbers.isNotEmpty)
              'seat_numbers': seatNumbers,
            if (seatBreakdown != null && seatBreakdown.isNotEmpty)
              'seat_breakdown': seatBreakdown,
            if (passengerId != null && passengerId > 0)
              'passenger_id': passengerId,
            if (contactNumber != null && contactNumber.trim().isNotEmpty)
              'contact_number': contactNumber.trim(),
            if (email != null && email.trim().isNotEmpty)
              'email': email.trim(),
          }),
        );
      }

      final dynamic decoded = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          decoded is Map<String, dynamic> &&
          decoded['checkout_url'] != null) {
        return decoded;
      }

      final message = decoded is Map<String, dynamic> ? decoded['message']?.toString() : null;
      throw ApiException(message ?? 'Unable to initialize PayMongo payment session.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw mapNetworkException(e, Uri.parse('${ApiConfig.baseUrl}/api/payments/checkout'));
    }
  }

  Future<Map<String, List<Booking>>> fetchPassengerBookings({
      String? passengerName,
      int? passengerId}) async {
    try {
      final response = await _sendRequest(
        method: 'GET',
        path: '/api/passenger/bookings',
        headers: {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
        },
        queryParameters: {
          if (passengerId != null && passengerId > 0)
            'passenger_id': passengerId.toString(),
          if (passengerName != null && passengerName.trim().isNotEmpty)
            'passenger_name': passengerName.trim(),
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (response.statusCode != 200) {
        throw ApiException('Unable to load passenger bookings.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return {'pending': [], 'confirmed': [], 'cancelled': []};
      }

      List<Booking> parseList(dynamic listRaw) {
        if (listRaw is! List) return [];
        return listRaw
            .whereType<Map>()
            .map((item) => Booking.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }

      return {
        'pending': parseList(decoded['pending']),
        'confirmed': parseList(decoded['confirmed']),
        'cancelled': parseList(decoded['cancelled']),
        'all': parseList(decoded['all']),
      };
    } catch (e) {
      if (e is ApiException) rethrow;
      throw mapNetworkException(e, Uri.parse('${ApiConfig.baseUrl}/api/passenger/bookings'));
    }
  }
}

List<Schedule> excludeDepartedSchedules(List<Schedule> schedules) {
  return schedules;
}