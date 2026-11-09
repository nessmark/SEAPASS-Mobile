import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/widgets/assistant/assistant_navigation.dart';

void main() {
  final today = DateTime(2026, 11, 9);

  group('AssistantNavigationRequest.fromEvent', () {
    test('maps every passenger page and its aliases to the real tabs', () {
      final cases = <String, int>{
        'trips': 0,
        'home': 0,
        'schedules': 0,
        'bookings': 1,
        'tickets': 1,
        'my_bookings': 1,
        'advisories': 2,
        'notices': 2,
        'profile': 3,
        'account': 3,
        'My_Account': 3,
      };
      for (final entry in cases.entries) {
        final request = AssistantNavigationRequest.fromEvent({'type': 'navigate', 'page': entry.key}, today: today);
        expect(request, isNotNull, reason: entry.key);
        expect(request!.tabIndex, entry.value, reason: entry.key);
      }
    });

    test('refuses admin, staff and unknown pages', () {
      for (final page in ['dashboard', 'fleet', 'scanner', 'sms', 'reports', '', 'checkout', 'payment']) {
        expect(AssistantNavigationRequest.fromEvent({'page': page}, today: today), isNull, reason: page);
      }
      expect(AssistantNavigationRequest.fromEvent(null), isNull);
    });

    test('start_booking prefill keeps only search fields and never a pay or confirm flag', () {
      final request = AssistantNavigationRequest.fromEvent({
        'type': 'navigate',
        'page': 'trips',
        'path': 'trips?trip_id=12',
        'args': {
          'trip_id': 12,
          'date': '2026-11-12',
          'route': 'San Jose → Surigao',
          'seats': 3,
          'pay': true,
          'confirm': true,
          'auto_book': true,
          'payment_method': 'gcash',
          'token': 'abc',
        },
      }, today: today)!;
      expect(request.page, 'trips');
      expect(request.prefill, {
        'trip_id': 12,
        'date': '2026-11-12',
        'route': 'San Jose → Surigao',
        'from': 'San Jose',
        'to': 'Surigao',
        'seats': 3,
      });
    });

    test('drops past dates, bad dates and out of range seat counts', () {
      final request = AssistantNavigationRequest.fromEvent({
        'page': 'trips',
        'args': {'date': '2026-11-08', 'seats': 0, 'trip_id': -4},
      }, today: today)!;
      expect(request.prefill, isEmpty);
      final bad = AssistantNavigationRequest.sanitizeBookingPrefill(
          {'date': 'next friday', 'seats': 11, 'route': 'x' * 101}, today: today);
      expect(bad, isEmpty);
      final todayOk = AssistantNavigationRequest.sanitizeBookingPrefill({'date': '2026-11-09', 'seats': '10'}, today: today);
      expect(todayOk, {'date': '2026-11-09', 'seats': 10});
    });

    test('booking prefill is ignored for pages other than trips', () {
      final request = AssistantNavigationRequest.fromEvent({
        'page': 'bookings',
        'args': {'trip_id': 12, 'seats': 2},
      }, today: today)!;
      expect(request.prefill, isEmpty);
    });
  });

  group('assistantPortOf', () {
    test('reads the departure port from route text and explicit origins', () {
      expect(assistantPortOf('Surigao City → San Jose, Dinagat Islands', first: true), 'Surigao');
      expect(assistantPortOf('San Jose to Surigao', first: true), 'San Jose');
      expect(assistantPortOf('Dinagat - Surigao', first: true), 'San Jose');
      expect(assistantPortOf('SanJose'), 'San Jose');
      expect(assistantPortOf('Cebu'), isNull);
      expect(assistantPortOf(null), isNull);
    });

    test('an explicit origin wins over the route text', () {
      final prefill = AssistantNavigationRequest.sanitizeBookingPrefill(
          {'route': 'Surigao → San Jose', 'from': 'San Jose'}, today: today);
      expect(prefill['from'], 'San Jose');
      expect(prefill['to'], 'Surigao');
    });
  });

  test('the navigation bus hands a request over once', () {
    final request = AssistantNavigationRequest.fromEvent({'page': 'bookings'}, today: today);
    AssistantNavigationBus.pending.value = request;
    expect(AssistantNavigationBus.take(), request);
    expect(AssistantNavigationBus.take(), isNull);
  });
}
