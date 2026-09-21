import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/main.dart';
import 'package:seapass_passenger_app/screens/auth_gate.dart';

void main() {
  testWidgets('SeaPass Passenger App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // MyApp opens on the AuthGate, which decides where the session goes.
    expect(find.byType(AuthGate), findsOneWidget);

    // AuthGate shows a progress indicator while it restores the session, so
    // the tree never settles — pump a couple of frames instead.
    await tester.pump(const Duration(milliseconds: 300));
  });
}

