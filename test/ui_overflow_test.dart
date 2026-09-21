// 360px layout guard.
//
// Every screen has to hold on the narrowest phone we support, in both themes.
// Splash and AuthGate are deliberately not covered: they start a timer on
// build, which a widget test cannot settle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/models/passenger_booking_models.dart';
import 'package:seapass_passenger_app/models/route_fare.dart';
import 'package:seapass_passenger_app/models/schedule.dart';
import 'package:seapass_passenger_app/screens/checkout/steps/checkout_step_details.dart';
import 'package:seapass_passenger_app/screens/checkout/steps/checkout_step_payment.dart';
import 'package:seapass_passenger_app/screens/checkout/steps/checkout_step_seat_map.dart';
import 'package:seapass_passenger_app/theme/app_theme.dart';

final schedule = Schedule(
  id: 7,
  from: 'Surigao City',
  to: 'San Jose, Dinagat Islands',
  departureTime: '08:00',
  boatName: 'MV Dinagat Express II',
  status: 'scheduled',
  date: 'Sep 21, 2026',
  time: '08:00 AM',
  availableSeats: 24,
  capacity: 40,
);

const fare = RouteFare(regular: 1060, student: 848, senior: 848);

List<PassengerDetail> makePassengers() {
  final a = PassengerDetail(
      index: 1,
      category: 'regular',
      initialGivenNames: 'Maria Concepcion',
      initialLastName: 'Villanueva-Santos');
  final b = PassengerDetail(
      index: 2,
      category: 'senior',
      initialGivenNames: 'Juan',
      initialLastName: 'Dela Cruz',
      initialIdNumber: 'SC-99');
  a.assignedSeat = '4D';
  b.assignedSeat = '4E';
  return [a, b];
}

List<VesselSeat> makeSeats() {
  final seats = <VesselSeat>[];
  for (var r = 1; r <= 8; r++) {
    for (final c in ['A', 'B', 'C', 'D', 'E']) {
      seats.add(VesselSeat(
        seatNumber: '$r$c',
        row: r,
        column: c,
        isBooked: r == 2,
      ));
    }
  }
  seats.firstWhere((s) => s.seatNumber == '4D').assignedPassengerIndex = 1;
  return seats;
}

const methods = [
  PaymentMethodOption(
    id: 'paymongo_gcash',
    name: 'GCash / QR Ph (PayMongo)',
    subtitle: 'Instant dynamic QR payment via GCash or banking app',
    icon: Icons.qr_code_scanner_rounded,
    badge: 'Dynamic QR',
  ),
];

Widget host(Widget child, ThemeData theme) => MediaQuery(
      data: const MediaQueryData(size: Size(360, 780)),
      child: MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: child,
          ),
        ),
      ),
    );

void main() {
  for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    final theme = entry.value;

    testWidgets('step details holds at 360 (${entry.key})', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final passengers = makePassengers();
      await tester.pumpWidget(host(
        CheckoutStepDetails(
          schedule: schedule,
          fare: fare,
          regularCount: 1,
          studentCount: 0,
          seniorCount: 1,
          totalSeats: 2,
          totalPrice: 1908,
          passengers: passengers,
          onIncrementCategory: (_) {},
          onDecrementCategory: (_) {},
          onProceedToSeats: () {},
          onPassengerFormUpdated: () {},
        ),
        theme,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final p in passengers) {
        p.dispose();
      }
    });

    testWidgets('step seat map holds at 360 (${entry.key})', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final passengers = makePassengers();
      await tester.pumpWidget(host(
        CheckoutStepSeatMap(
          schedule: schedule,
          passengers: passengers,
          seats: makeSeats(),
          activePassengerIndex: 0,
          totalSeats: 2,
          totalRows: 8,
          isRefreshing: true,
          onActivePassengerChanged: (_) {},
          onSeatTapped: (_) {},
          onBackToDetails: () {},
          onProceedToPayment: () {},
          onManualRefresh: () {},
        ),
        theme,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final p in passengers) {
        p.dispose();
      }
    });

    testWidgets('step payment holds at 360 (${entry.key})', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final passengers = makePassengers();
      await tester.pumpWidget(host(
        CheckoutStepPayment(
          schedule: schedule,
          fare: fare,
          regularCount: 1,
          studentCount: 0,
          seniorCount: 1,
          totalPrice: 1908,
          passengers: passengers,
          formattedHoldTime: '14:59',
          paymentMethods: methods,
          selectedPaymentId: 'paymongo_gcash',
          isSubmitting: false,
          onPaymentMethodSelected: (_) {},
          onBackToSeats: () {},
          onConfirmAndPay: () {},
        ),
        theme,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final p in passengers) {
        p.dispose();
      }
    });

  }
}
