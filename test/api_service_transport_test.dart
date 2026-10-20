import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seapass_passenger_app/config/api_config.dart';
import 'package:seapass_passenger_app/services/api_service.dart';

void main() {
  test('profile PATCH sends a write with its body instead of a successful GET',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/passenger/profile');
      expect(request.body, '{"name":"Updated passenger"}');
      return http.Response('{"message":"Profile updated."}', 200);
    });
    await ApiService.request(
        method: 'PATCH',
        endpoint: '/api/passenger/profile',
        body: '{"name":"Updated passenger"}',
        requiresAuth: false,
        client: client);
    client.close();
  });

  test('an uncertain booking write is never retried against a fallback server',
      () async {
    ApiConfig.customBaseUrl = 'http://127.0.0.1:8000';
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      throw TimeoutException('Response lost after submission');
    });
    await expectLater(
        ApiService.request(
            method: 'POST',
            endpoint: '/api/payments/checkout',
            body: '{}',
            requiresAuth: false,
            client: client),
        throwsA(isA<TimeoutException>()));
    expect(requests, 1);
    client.close();
    ApiConfig.customBaseUrl = '';
  });
}
