import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seapass_passenger_app/config/api_config.dart';
import 'package:seapass_passenger_app/services/api_service.dart';
import 'package:seapass_passenger_app/services/assistant_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> _token() async => 'test-token';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiConfig.customBaseUrl = 'http://127.0.0.1:8000';
    ApiService.setAuthToken('test-token');
  });

  tearDown(() {
    ApiConfig.customBaseUrl = '';
    ApiService.clearAuthHeader();
  });

  group('classify', () {
    test('no network is offline, a silent server is unreachable', () {
      expect(AssistantService.classify(const SocketException('Failed host lookup: seapass')).kind,
          AssistantFailureKind.offline);
      expect(AssistantService.classify(const SocketException('x', osError: OSError('Network is unreachable', 101))).kind,
          AssistantFailureKind.offline);
      expect(AssistantService.classify(const SocketException('Connection refused')).kind,
          AssistantFailureKind.unreachable);
      expect(AssistantService.classify(TimeoutException('slow')).kind, AssistantFailureKind.unreachable);
      expect(AssistantService.classify(http.ClientException('closed')).kind, AssistantFailureKind.unreachable);
      expect(AssistantService.classify(StateError('x')).kind, AssistantFailureKind.unavailable);
    });

    test('a known offline device wins over the error type', () {
      expect(AssistantService.classify(TimeoutException('slow'), online: false).kind, AssistantFailureKind.offline);
    });

    test('every state has plain copy and only sensible retries', () {
      for (final kind in AssistantFailureKind.values) {
        final failure = AssistantUnavailable(kind);
        expect(failure.title, isNotEmpty);
        expect(failure.message, isNotEmpty);
        expect(failure.message.contains('—'), isFalse);
      }
      expect(const AssistantUnavailable(AssistantFailureKind.offline).canRetry, isTrue);
      expect(const AssistantUnavailable(AssistantFailureKind.unreachable).canRetry, isTrue);
      expect(const AssistantUnavailable(AssistantFailureKind.signedOut).canRetry, isFalse);
      expect(const AssistantUnavailable(AssistantFailureKind.notConfigured).canRetry, isFalse);
    });
  });

  group('bootstrap', () {
    test('no token is signed out without calling the server', () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      await expectLater(
        AssistantService.bootstrap(label: 'Trips', path: 'trips', client: client, readToken: () async => null),
        throwsA(isA<AssistantUnavailable>().having((e) => e.kind, 'kind', AssistantFailureKind.signedOut)),
      );
      expect(calls, 0);
    });

    test('sends the bearer token and returns the page context', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/assistant/status');
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response(jsonEncode({'configured': true, 'identity': 'passenger-7'}), 200);
      });
      final config = await AssistantService.bootstrap(
          label: 'Trips', path: 'trips', client: client, readToken: _token, mountedTargets: ['date_rail']);
      expect(config['token'], 'test-token');
      expect(config['identity'], 'passenger-7');
      final context = config['context'] as Map<String, dynamic>;
      expect(context['path'], 'trips');
      expect((context['targets'] as List).map((t) => t['id']), ['date_rail']);
      expect(context['text'], contains('never claim a booking or payment was made'));
    });

    Future<AssistantFailureKind> failWith(http.Response response) async {
      final client = MockClient((_) async => response);
      try {
        await AssistantService.bootstrap(label: 'Trips', path: 'trips', client: client, readToken: _token);
      } on AssistantUnavailable catch (error) {
        return error.kind;
      }
      fail('bootstrap should have failed');
    }

    test('maps server answers to their own states', () async {
      expect(await failWith(http.Response(jsonEncode({'configured': false}), 200)), AssistantFailureKind.notConfigured);
      expect(await failWith(http.Response(jsonEncode({'configured': true}), 200)), AssistantFailureKind.signedOut);
      expect(await failWith(http.Response('{"message":"Unauthenticated."}', 401)), AssistantFailureKind.signedOut);
      expect(await failWith(http.Response('<html>bad gateway</html>', 502)), AssistantFailureKind.unreachable);
      expect(await failWith(http.Response('{"message":"Busy, try later."}', 503)), AssistantFailureKind.unavailable);
      expect(await failWith(http.Response('{"message":"Forbidden."}', 403)), AssistantFailureKind.unavailable);
    });

    test('a 503 shows the server message, never raw provider data', () async {
      final client = MockClient((_) async => http.Response('{"message":"The assistant is busy."}', 503));
      try {
        await AssistantService.bootstrap(label: 'Trips', path: 'trips', client: client, readToken: _token);
        fail('should fail');
      } on AssistantUnavailable catch (error) {
        expect(error.message, 'The assistant is busy.');
      }
    });

    test('a dropped connection is unreachable', () async {
      final client = MockClient((_) async => throw const SocketException('Connection refused'));
      await expectLater(
        AssistantService.bootstrap(label: 'Trips', path: 'trips', client: client, readToken: _token),
        throwsA(isA<AssistantUnavailable>().having((e) => e.kind, 'kind', AssistantFailureKind.unreachable)),
      );
    });
  });

  test('page context names the screen and only its own guide targets', () {
    final checkout = AssistantService.pageContext(
        label: 'Booking Checkout', path: 'checkout', details: 'Step 2 of 3', mountedTargets: ['seat_map', 'date_rail']);
    expect((checkout['targets'] as List).map((t) => t['id']), ['seat_map']);
    expect(checkout['text'], contains('Booking Checkout'));
    expect(checkout['text'], contains('Step 2 of 3'));
    final unknown = AssistantService.pageContext(label: 'Other', path: 'other');
    expect(unknown['targets'], isEmpty);
  });

  test('the embed page sits at the site root, not under /api', () {
    ApiConfig.customBaseUrl = 'https://seapass.example.ph/api';
    expect(AssistantService.embedUri.toString(), 'https://seapass.example.ph/assistant/embed');
  });
}
