import 'package:flutter/material.dart';

import '../services/passenger_session.dart';
import '../services/token_storage_service.dart';
import '../widgets/app_palette.dart';
import '../widgets/seapass_logo.dart';
import 'login_screen.dart';
import 'main_navigation_screen.dart';

/// Full-screen splash / loading screen shown while the app initialises.
///
/// Displays the SeaPass ferry logo with a gentle pulse animation, then
/// inspects stored token & role to route to LoginScreen, ScannerHomeScreen, or MainNavigationScreen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String routeName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Verify active session token & role in local storage on startup
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;

      await PassengerSession.loadSession();
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
        // Case 3: Authenticated as Passenger -> MainNavigationScreen
        targetScreen = const MainNavigationScreen();
      } else {
        // Fallback: Clear invalid state and route to LoginScreen
        await TokenStorageService.deleteToken();
        await PassengerSession.clear();
        targetScreen = const LoginScreen();
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => targetScreen,
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ferry logo
                const SeaPassLogo(size: 96),
                const SizedBox(height: 20),

                // App name
                Text(
                  'SeaPass',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: AppColors.of(context).text,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'San Jose Port — Passenger',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.of(context).text3,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 48),

                // Loading indicator
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppPalette.teal500.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
