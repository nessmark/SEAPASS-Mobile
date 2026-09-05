import 'package:flutter_test/flutter_test.dart';
import 'package:seapass_passenger_app/main.dart';
import 'package:seapass_passenger_app/screens/splash_screen.dart';

void main() {
  testWidgets('SeaPass Passenger App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that SplashScreen renders initially
    expect(find.byType(SplashScreen), findsOneWidget);

    // Advance clock past the splash transition timer
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}

