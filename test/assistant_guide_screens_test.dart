// "Show me" on the pushed passenger screens, at 360x800 with real widgets.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/models/booking.dart';
import 'package:seapass_passenger_app/models/passenger_booking_models.dart';
import 'package:seapass_passenger_app/models/route_fare.dart';
import 'package:seapass_passenger_app/models/schedule.dart';
import 'package:seapass_passenger_app/screens/checkout/steps/checkout_step_payment.dart';
import 'package:seapass_passenger_app/screens/view_ticket_screen.dart';
import 'package:seapass_passenger_app/services/assistant_service.dart';
import 'package:seapass_passenger_app/theme/app_theme.dart';
import 'package:seapass_passenger_app/widgets/assistant/page_guide.dart';

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

const booking = Booking(
  id: '12',
  referenceNumber: 'SP-2026-0921-0042',
  passengerName: 'Marilou Bautista',
  route: 'Surigao City → San Jose',
  date: 'Sep 21, 2026',
  time: '08:00 AM',
  boatName: 'MB Dinagat Star',
  seatCount: 2,
  seatNumbers: ['4D', '4E'],
  totalPrice: 1908.0,
  status: 'confirmed',
  showViewTicket: true,
);

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    testWidgets('pointing at Pay never presses it (${entry.key})', (tester) async {
      phone(tester);
      var payments = 0;
      final passenger = PassengerDetail(index: 1, category: 'regular', initialGivenNames: 'Juan', initialLastName: 'Cruz')
        ..assignedSeat = '4D';
      addTearDown(passenger.dispose);
      await tester.pumpWidget(MaterialApp(
        theme: entry.value,
        home: Scaffold(
          body: Builder(
            builder: (context) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(children: [
                TextButton(
                  onPressed: () => showSeaPassPageGuide(context, 'checkout', {
                    'action': {
                      'type': 'highlight_element',
                      'args': {'target': 'confirm_pay'}
                    }
                  }),
                  child: const Text('Point'),
                ),
                CheckoutStepPayment(
                  schedule: schedule,
                  fare: const RouteFare(regular: 1060, student: 848, senior: 848),
                  regularCount: 1,
                  studentCount: 0,
                  seniorCount: 0,
                  totalPrice: 1060,
                  passengers: [passenger],
                  formattedHoldTime: '14:59',
                  paymentMethods: const [
                    PaymentMethodOption(
                      id: 'paymongo_gcash',
                      name: 'GCash / QR Ph (PayMongo)',
                      subtitle: 'Pay with GCash or a banking app',
                      icon: Icons.qr_code_scanner_rounded,
                    ),
                  ],
                  selectedPaymentId: 'paymongo_gcash',
                  isSubmitting: false,
                  onPaymentMethodSelected: (_) {},
                  onBackToSeats: () {},
                  onConfirmAndPay: () => payments++,
                ),
              ]),
            ),
          ),
        ),
      ));
      final targets = AssistantService.pageContext(
              label: 'Booking Checkout', path: 'checkout', mountedTargets: mountedGuideTargets())['targets'] as List;
      expect(targets.map((t) => t['id']), containsAll(['payment_methods', 'fare_breakdown', 'confirm_pay']));
      expect(targets.map((t) => t['id']), isNot(contains('seat_map')), reason: 'only what is on this step');

      await tester.tap(find.text('Point'));
      await tester.pumpAndSettle();
      expect(find.text('Pay reserves your seats and opens payment. The assistant never presses it for you.'),
          findsOneWidget);
      final pay = tester.getRect(find.byKey(const ValueKey('checkout-pay')));
      expect(pay.top, greaterThanOrEqualTo(0));
      expect(pay.bottom, lessThanOrEqualTo(800));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(payments, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the boarding pass tour visits the summary, the QR and Save', (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const ViewTicketScreen(booking: booking)));
    await tester.pump();
    final context = tester.element(find.byType(ViewTicketScreen));
    final done = showSeaPassPageGuide(context, 'ticket');
    await tester.pumpAndSettle();
    for (final (step, title) in [(1, 'Your trip'), (2, 'Boarding QR'), (3, 'Keep a copy')]) {
      expect(find.text('Step $step of 3'), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(step == 3 ? 'Done' : 'Next'));
      await tester.pumpAndSettle();
    }
    expect(await done, isTrue);
    expect(find.text('Keep a copy'), findsNothing);
  });
}
