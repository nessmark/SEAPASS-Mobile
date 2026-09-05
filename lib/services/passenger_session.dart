class PassengerSession {
  static String name = '';
  static String email = '';
  static String phone = '';
  static int passengerId = 0;

  static bool get isLoggedIn => passengerId > 0 || email.isNotEmpty;

  static void clear() {
    name = '';
    email = '';
    phone = '';
    passengerId = 0;
  }
}