import 'package:flutter/material.dart';

import 'app_navigator.dart';
import 'models/booking.dart';
import 'models/schedule.dart';
import 'screens/advisories_screen.dart';
import 'screens/auth_gate.dart';
import 'screens/booking_checkout_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/passenger_home_screen.dart';
import 'screens/scanner_home_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/view_ticket_screen.dart';
import 'package:provider/provider.dart';

import 'providers/advisory_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdvisoryProvider()..fetchUnreadCount()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeaPass',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      navigatorObservers: [appRouteObserver],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      routes: {
        AuthGate.routeName: (context) => const AuthGate(),
        SplashScreen.routeName: (context) => const SplashScreen(),
        LoginScreen.routeName: (context) => const LoginScreen(),
        PassengerHomeScreen.routeName: (context) => const PassengerHomeScreen(),
        ScannerHomeScreen.routeName: (context) => const ScannerHomeScreen(),
        AdvisoriesScreen.routeName: (context) => const AdvisoriesScreen(),
        SignupScreen.routeName: (context) => const SignupScreen(),
        OtpVerificationScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as OtpVerificationArguments?;
          return OtpVerificationScreen(arguments: args);
        },
        ViewTicketScreen.routeName: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return ViewTicketScreen(
            booking: args is Booking ? args : null,
          );
        },
        BookingCheckoutScreen.routeName: (context) {
          final schedule =
              ModalRoute.of(context)!.settings.arguments as Schedule;
          return BookingCheckoutScreen(schedule: schedule);
        },
      },
    );
  }
}
