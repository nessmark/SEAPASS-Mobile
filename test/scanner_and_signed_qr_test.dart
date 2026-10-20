import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/models/booking.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Booking Signed QR and Passenger Tickets Parsing Tests', () {
    test('Booking.fromJson parses passenger_tickets with signed qr_payload', () {
      final json = {
        'id': 101,
        'reference_number': 'SP-000300',
        'trip_schedule_id': 12,
        'passenger_name': 'Jay Canete',
        'seat_numbers': ['1A', '1B'],
        'status': 'confirmed',
        'amount_collected': 900.0,
        'route': 'Batangas to Calapan',
        'trip_date': '2026-10-21',
        'departure_time_slot': '08:00 AM',
        'boat_name': 'FastCat M1',
        'passenger_tickets': [
          {
            'seat': '1A',
            'name': 'Jay Canete',
            'category': 'regular',
            'fare': 450.0,
            'qr_payload': jsonEncode({
              'booking_id': 101,
              'reference_number': 'SP-000300',
              'seat': '1A',
              'passenger_name': 'Jay Canete',
              'category': 'regular',
              'boarding_token': 'hmac_signed_token_for_seat_1a',
              'timestamp': 1792470000,
            }),
          },
          {
            'seat': '1B',
            'name': 'Companion Canete',
            'category': 'regular',
            'fare': 450.0,
            'qr_payload': jsonEncode({
              'booking_id': 101,
              'reference_number': 'SP-000300',
              'seat': '1B',
              'passenger_name': 'Companion Canete',
              'category': 'regular',
              'boarding_token': 'hmac_signed_token_for_seat_1b',
              'timestamp': 1792470000,
            }),
          },
        ],
      };

      final booking = Booking.fromJson(json);

      expect(booking.referenceNumber, equals('SP-000300'));
      expect(booking.seatNumbers, equals(['1A', '1B']));
      expect(booking.prebuiltTickets, isNotNull);
      expect(booking.prebuiltTickets!.length, equals(2));

      final t1 = booking.prebuiltTickets![0];
      expect(t1.seat, equals('1A'));
      expect(t1.name, equals('Jay Canete'));
      expect(t1.qrPayload, contains('hmac_signed_token_for_seat_1a'));

      final t2 = booking.prebuiltTickets![1];
      expect(t2.seat, equals('1B'));
      expect(t2.name, equals('Companion Canete'));
      expect(t2.qrPayload, contains('hmac_signed_token_for_seat_1b'));

      // Verify passengerTickets exposes signed qrPayload
      final tickets = booking.passengerTickets;
      final ticket1 = tickets.firstWhere((t) => t.seat == '1A');
      expect(ticket1.qrPayload, contains('hmac_signed_token_for_seat_1a'));
      final decoded1 = jsonDecode(ticket1.qrPayload!) as Map<String, dynamic>;
      expect(decoded1['boarding_token'], equals('hmac_signed_token_for_seat_1a'));
      expect(decoded1['seat'], equals('1A'));

      final ticket2 = tickets.firstWhere((t) => t.seat == '1B');
      expect(ticket2.qrPayload, contains('hmac_signed_token_for_seat_1b'));
      final decoded2 = jsonDecode(ticket2.qrPayload!) as Map<String, dynamic>;
      expect(decoded2['boarding_token'], equals('hmac_signed_token_for_seat_1b'));
      expect(decoded2['seat'], equals('1B'));
    });

    test('PassengerTicketInfo toQrPayload falls back gracefully when qrPayload is absent', () {
      const ticket = PassengerTicketInfo(
        id: 'P1',
        name: 'Solo Passenger',
        seat: '3C',
        category: 'regular',
        individualFare: 450.0,
      );

      final payload = ticket.toQrPayload(bookingRef: 'SP-000301', vessel: 'FastCat M2');
      expect(payload['booking_ref'], equals('SP-000301'));
      expect(payload['seat'], equals('3C'));
      expect(payload['vessel'], equals('FastCat M2'));
      expect(payload['passenger_name'], equals('Solo Passenger'));
    });
  });

}
