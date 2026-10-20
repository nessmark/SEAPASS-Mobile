import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seapass_passenger_app/services/api_service.dart';
import 'package:seapass_passenger_app/services/api_exception.dart';
import 'package:seapass_passenger_app/services/passenger_data_service.dart';
import 'package:seapass_passenger_app/services/payment_verification_service.dart';
import 'package:seapass_passenger_app/screens/checkout/paymongo_webview_screen.dart';

void main() {
  setUp(() => ApiService.setAuthToken('local-test-token'));
  tearDown(ApiService.clearAuthHeader);

  test('a success redirect is only a same-origin hint, never proof of payment',
      () {
    final base = Uri.parse('http://127.0.0.1:8000');
    expect(
        PaymentVerificationService.isReturnUrl(
            'http://127.0.0.1:8000/payment/success?status=paid', base),
        isTrue);
    expect(
        PaymentVerificationService.isReturnUrl(
            'https://unrelated.example/payment/success?paid=true', base),
        isFalse);
    expect(
        PaymentVerificationService.isReturnUrl('mailto:paid@example.com', base),
        isFalse);
    expect(PaymentVerificationService.classify({'status': 'confirmed'}),
        CheckoutVerification.waiting);
    expect(
        PaymentVerificationService.classify({
          'status': 'pending',
          'payment_received_at': '2026-10-20T04:00:00Z'
        }),
        CheckoutVerification.waiting);
    expect(
        PaymentVerificationService.classify({
          'status': 'to_be_confirmed',
          'payment_received_at': '2026-10-20T04:00:00Z'
        }),
        CheckoutVerification.paid);
    expect(
        PaymentVerificationService.classify({
          'status': 'confirmed',
          'payment_received_at': '2026-10-20T04:00:00Z',
          'payment_review_required': true
        }),
        CheckoutVerification.review);
    expect(
        PaymentVerificationService.classify({
          'status': 'expired',
          'payment_received_at': '2026-10-20T04:00:00Z'
        }),
        CheckoutVerification.expired);
  });

  test('a paid booking with a different reference cannot confirm this checkout',
      () async {
    final client = MockClient((request) async => http.Response(
        jsonEncode({
          'all': [
            {
              'reference_number': 'OTHER',
              'status': 'confirmed',
              'payment_received_at': '2026-10-20T04:00:00Z'
            }
          ]
        }),
        200));
    expect(await PaymentVerificationService(client: client).check('TARGET'),
        CheckoutVerification.missing);
    client.close();
  });

  test('a 503 retains the owned hold ID so retry submits that reservation',
      () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.method, 'POST');
      if (requests == 1) {
        return http.Response(
            jsonEncode({
              'message': 'Provider unavailable',
              'booking': {
                'id': 42,
                'reservation_expires_at': '2026-10-20T04:15:00Z'
              }
            }),
            503);
      }
      expect(jsonDecode(request.body), {'booking_id': 42});
      return http.Response(
          jsonEncode({
            'checkout_url': 'https://checkout.paymongo.com/example',
            'booking': {'id': 42}
          }),
          200);
    });
    final service = PassengerDataService(client: client);
    CheckoutFailure? failure;
    try {
      await service.createPayMongoCheckoutSession(
          scheduleId: 1, seatCount: 1, seatNumbers: ['1A']);
    } on CheckoutFailure catch (error) {
      failure = error;
    }
    expect(failure?.bookingId, 42);
    expect(failure?.expiresAt, isNotNull);
    final retry = await service.createPayMongoCheckoutSession(
        bookingId: failure!.bookingId);
    expect(retry['booking']['id'], 42);
    expect(requests, 2);
    client.close();
  });

  test(
      'profile API sends PATCH and surfaces backend validation instead of local success',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(jsonDecode(request.body),
          {'name': 'Updated Passenger', 'phone': '09171234567'});
      return http.Response(
          '{"message":"Invalid contact","errors":{"phone":["Invalid phone number."]}}',
          422);
    });
    await expectLater(
        PassengerDataService(client: client)
            .updateProfile(name: ' Updated Passenger ', phone: '09171234567'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', 'Invalid phone number.')));
    client.close();
  });

  test('scanner transport preserves the actual signed per-seat payload',
      () async {
    final client = MockClient((request) async {
      final body = jsonDecode(request.body);
      expect(body['boarding_token'], 'signed-seat-token');
      expect(body['seat'], '1A');
      expect(body['reference_number'], 'TARGET');
      return http.Response('{"success":true,"data":{}}', 200);
    });
    await PassengerDataService(client: client)
        .verifyTicket('TARGET', scannedJson: {
      'reference_number': 'TARGET',
      'boarding_token': 'signed-seat-token',
      'seat': '1A'
    });
    client.close();
  });

  testWidgets(
      'checkout opens the real link and waits for a verified server receipt',
      (tester) async {
    var record = <String, dynamic>{
      'reference_number': 'TARGET',
      'status': 'confirmed'
    };
    final client = MockClient((request) async => http.Response(
        jsonEncode({
          'all': [record]
        }),
        200));
    String? opened;
    PaymentResult? result;
    await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
                    body: Column(children: [
                  TextButton(
                      onPressed: () async {
                        final value = await Navigator.push<PaymentResult>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PayMongoWebViewScreen(
                                      checkoutUrl:
                                          'https://checkout.paymongo.com/real-link',
                                      referenceNumber: 'TARGET',
                                      totalAmount: 600,
                                      verificationService:
                                          PaymentVerificationService(
                                              client: client),
                                      openCheckout: (url) => opened = url,
                                    )));
                        setState(() => result = value);
                      },
                      child: const Text('Start')),
                  Text('Result: $result'),
                ])))));
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open secure checkout'));
    expect(opened, 'https://checkout.paymongo.com/real-link');
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(
        find.text(
            'Payment has not been verified yet. Complete checkout, then check again.'),
        findsOneWidget);
    record = {...record, 'payment_received_at': '2026-10-20T04:00:00Z'};
    await tester.tap(find.text('Check payment status'));
    await tester.pumpAndSettle();
    expect(result, PaymentResult.success);
    await tester.pumpWidget(const SizedBox());
    client.close();
  });
}
