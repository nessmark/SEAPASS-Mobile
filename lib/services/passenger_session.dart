import 'package:shared_preferences/shared_preferences.dart';

class PassengerSession {
  static String name = '';
  static String email = '';
  static String phone = '';
  static int passengerId = 0;
  static String role = 'passenger';
  static String assignedPort = '';

  static bool get isLoggedIn => (passengerId > 0 || email.isNotEmpty);
  static bool get isScanner => isLoggedIn && role.toLowerCase() == 'scanner';

  static Future<void> saveSession({
    required String name,
    required String email,
    required String phone,
    required int passengerId,
    required String role,
    String? assignedPort,
  }) async {
    PassengerSession.name = name;
    PassengerSession.email = email;
    PassengerSession.phone = phone;
    PassengerSession.passengerId = passengerId;
    PassengerSession.role = role.toLowerCase();
    PassengerSession.assignedPort = assignedPort ?? '';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_name', name);
      await prefs.setString('session_email', email);
      await prefs.setString('session_phone', phone);
      await prefs.setInt('session_passengerId', passengerId);
      await prefs.setString('session_role', PassengerSession.role);
      await prefs.setString('session_assignedPort', PassengerSession.assignedPort);
    } catch (_) {}
  }

  static Future<void> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      name = prefs.getString('session_name') ?? '';
      email = prefs.getString('session_email') ?? '';
      phone = prefs.getString('session_phone') ?? '';
      passengerId = prefs.getInt('session_passengerId') ?? 0;
      role = prefs.getString('session_role') ?? 'passenger';
      assignedPort = prefs.getString('session_assignedPort') ?? '';
    } catch (_) {}
  }

  static Future<void> clear() async {
    name = '';
    email = '';
    phone = '';
    passengerId = 0;
    role = 'passenger';
    assignedPort = '';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_name');
      await prefs.remove('session_email');
      await prefs.remove('session_phone');
      await prefs.remove('session_passengerId');
      await prefs.remove('session_role');
      await prefs.remove('session_assignedPort');
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
      await prefs.remove('user_data');
    } catch (_) {}
  }
}