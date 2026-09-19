import 'package:flutter/material.dart';

import '../services/passenger_session.dart';
import '../services/token_storage_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/seapass_logo.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

/// Role-Based Authentication Gate widget that checks stored token and role
/// on app startup and routes to the appropriate destination.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  static const String routeName = '/auth-gate';

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRoute();
  }

  Future<void> _checkAuthAndRoute() async {
    // Brief interval for smooth initialization and UI mounting
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    // Load persisted SharedPreferences session data
    await PassengerSession.loadSession();

    // Check stored auth state asynchronously
    final token = await TokenStorageService.getToken();
    final storedRole = await TokenStorageService.getUserRole();
    final userRole = (storedRole != null && storedRole.isNotEmpty)
        ? storedRole.toLowerCase()
        : PassengerSession.role.toLowerCase();

    if (!mounted) return;

    final bool hasValidToken =
        token != null && token.trim().isNotEmpty && token != 'null';

    Widget targetScreen;
    if (!hasValidToken) {
      // Case 1: No Token / Unauthenticated -> LoginScreen
      targetScreen = const LoginScreen();
    } else if (userRole == 'scanner') {
      // Scanner staff must NOT bypass login on app launch/restart.
      // Clear scanner session on startup so staff always authenticates via LoginScreen.
      await TokenStorageService.deleteToken();
      await PassengerSession.clear();
      targetScreen = const LoginScreen();
    } else if (userRole == 'passenger') {
      // Case 2: Authenticated as Passenger -> MainNavigationScreen
      targetScreen = const MainNavigationScreen();
    } else {
      // Fallback: Unrecognized role or expired session -> LoginScreen
      await TokenStorageService.deleteToken();
      await PassengerSession.clear();
      targetScreen = const LoginScreen();
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SeaPassLogo(size: 88),
            const SizedBox(height: 18),
            const Text(
              'SeaPass',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppPalette.darkText,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppPalette.mintGreen.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
