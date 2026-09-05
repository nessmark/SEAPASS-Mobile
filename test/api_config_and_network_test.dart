import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/config/api_config.dart';
import 'package:seapass_passenger_app/services/api_exception.dart';
import 'package:seapass_passenger_app/services/passenger_data_service.dart';

void main() {
  group('ApiConfig tests', () {
    setUp(() {
      ApiConfig.customBaseUrl = '';
    });

    test('Default baseUrl resolves expected port and endpoints', () {
      final base = ApiConfig.baseUrl;
      expect(base, contains(':8000'));
      expect(ApiConfig.passengerLoginEndpoint, equals('$base/api/passenger/login'));
      expect(ApiConfig.passengerSendOtpEndpoint, equals('$base/api/passenger/send-otp'));
      expect(ApiConfig.passengerVerifyRegisterEndpoint, equals('$base/api/passenger/verify-register'));
    });

    test('Custom base URL overrides default baseUrl', () {
      ApiConfig.customBaseUrl = 'http://192.168.1.9:8000';
      expect(ApiConfig.baseUrl, equals('http://192.168.1.9:8000'));

      // Handles trailing slash cleanly
      ApiConfig.customBaseUrl = 'http://192.168.1.9:8000/';
      expect(ApiConfig.baseUrl, equals('http://192.168.1.9:8000'));
    });

    test('fallbackBaseUrl provides correct alternate endpoint', () {
      // When on Wi-Fi (192.168.1.9), fallback should be USB (127.0.0.1)
      ApiConfig.customBaseUrl = 'http://192.168.1.9:8000';
      expect(ApiConfig.fallbackBaseUrl, equals('http://127.0.0.1:8000'));

      // When on USB (127.0.0.1), fallback should be Wi-Fi (192.168.1.9)
      ApiConfig.customBaseUrl = 'http://127.0.0.1:8000';
      expect(ApiConfig.fallbackBaseUrl, equals('http://192.168.1.9:8000'));
    });
  });

  group('PassengerDataService mapNetworkException tests', () {
    final testUri = Uri.parse('http://127.0.0.1:8000/api/passenger/login');

    test('Maps TimeoutException with actionable adb reverse advice', () {
      final timeout = TimeoutException('Connection timed out');
      final result = PassengerDataService.mapNetworkException(timeout, testUri);

      expect(result, isA<ApiException>());
      expect(result.message, contains('timed out'));
      expect(result.message, contains('adb reverse tcp:8000 tcp:8000'));
    });

    test('Maps SocketException with detail and troubleshooting guidance', () {
      const socketEx = SocketException('Connection refused', osError: OSError('Connection refused', 111));
      final result = PassengerDataService.mapNetworkException(socketEx, testUri);

      expect(result, isA<ApiException>());
      expect(result.message, contains('Unable to reach SeaPass server'));
      expect(result.message, contains('adb reverse tcp:8000 tcp:8000'));
    });

    test('Preserves existing ApiException without overwriting', () {
      final original = ApiException('Invalid email or password.');
      final result = PassengerDataService.mapNetworkException(original, testUri);

      expect(result.message, equals('Invalid email or password.'));
    });
  });
}
